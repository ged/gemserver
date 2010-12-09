#!/usr/bin/env ruby

require 'pp'
require 'pathname'
require 'rbconfig/datadir'
require 'erb'
require 'json'
require 'yaml'
require 'socket'
require 'tempfile'

require 'rubygems'
require 'rubygems/indexer'

require 'sinatra/base'

require 'gemserver'
require 'gemserver/authentication'


include ERB::Util

class Gemserver::App < Sinatra::Base
	include Gemserver::Authentication

	enable :sessions, :static, :logging, :dump_errors

	# The path to the gemserver's data directory
	SYSTEM_DATADIR = Pathname( Config.datadir('gemserver') )

	# The path to the directory that contains the gem data
	DEFAULT_GEMSDIR = SYSTEM_DATADIR + 'gems'

	# Default configuration values
	DEFAULTS = {
		'gemsdir' => DEFAULT_GEMSDIR,
	}

	# The name of the regular gems index
	RELEASE_GEM_INDEXFILE = "specs.%s.gz" % [ Gem.marshal_version ]

	# The name of the prerelease gems index
	PRERELEASE_GEM_INDEXFILE = "prerelease_specs.%s.gz" % [ Gem.marshal_version ]

	# The Marshal version of the current system
	MARSHAL_VERSION = Gem.marshal_version

	# The size of the read buffer when doing IO->IO copies
	READ_CHUNKSIZE = 65536

	# Approximate Time Constants (in seconds)
	MINUTES = 60
	HOURS   = 60  * MINUTES
	DAYS    = 24  * HOURS
	WEEKS   = 7   * DAYS
	MONTHS  = 30  * DAYS
	YEARS   = 365.25 * DAYS


	# Byte size constants
	KILOBYTE = 2 ** 10
	MEGABYTE = 2 ** 20
	GIGABYTE = 2 ** 30

	configure( :development ) do
		require 'sinatra/reloader'
		register Sinatra::Reloader
	end

	configure do
		if SYSTEM_DATADIR.exist?
			set :root, SYSTEM_DATADIR.to_s
		else
			set :root, Pathname( __FILE__ ).dirname.parent.parent + 'data/gemserver'
		end

		set :config, Proc.new {
			if configfile && configfile.exist?
				$stderr.puts "Loading configuration from %p" % [ configfile ]
				DEFAULTS.merge( YAML.load_file(configfile) )
			else
				$stderr.puts "Using default config: %p" % [ DEFAULTS ]
				DEFAULTS.dup
			end
		}

		set :gemsdir, Proc.new {
			path = if config['gemsdir']
				Pathname( config['gemsdir'] )
			else
				Pathname( DEFAULT_GEMSDIR )
			end

			$stderr.puts "Serving gems from: %s" % [ path ]
			path
		}

	end


	### Return a string describing the amount of time in the given number of
	### seconds in terms a human can understand easily.
	def time_delta_string( start_time )
		start_time = Time.parse( start_time ) unless start_time.is_a?( Time )
		seconds = Time.now - start_time

		return 'less than a minute' if seconds < 60

		if seconds < 50 * 60
			return "%d minute%s" % [seconds / 60, seconds/60 == 1 ? '' : 's']
		end

		return 'about an hour'					if seconds < 90 * MINUTES
		return "%d hours" % [seconds / HOURS]	if seconds < 18 * HOURS
		return 'one day' 						if seconds <  1 * DAYS
		return 'about a day' 					if seconds <  2 * DAYS
		return "%d days" % [seconds / DAYS] 	if seconds <  1 * WEEKS
		return 'about a week' 					if seconds <  2 * WEEKS
		return "%d weeks" % [seconds / WEEKS] 	if seconds <  3 * MONTHS
		return "%d months" % [seconds / MONTHS] if seconds <  2 * YEARS
		return "%d years" % [seconds / YEARS]
	end

	### Return a string describing an amount of data in a human-readable 
	### byte-suffixed form.
	def byte_suffix( bytes )
		bytes = bytes.to_f

		return case
			when bytes >= GIGABYTE then sprintf( "%0.1fG", bytes / GIGABYTE )
			when bytes >= MEGABYTE then sprintf( "%0.1fM", bytes / MEGABYTE )
			when bytes >= KILOBYTE then sprintf( "%0.1fK", bytes / KILOBYTE )
			else "%db" % [ bytes.ceil ]
			end
	end


	### Return a gem indexer for the configured gemsdir, creating it if necessary.
	def indexer
		@indexer ||= Gem::Indexer.new( self.options.gemsdir )
	end


	### Copy data from the +reader+ to the +writer+ in a memory-efficient manner.
	def copy_io( reader, writer )
		buf = ''
		bytes_copied = 0

		while reader.read( READ_CHUNKSIZE, buf )
			until buf.empty?
				bytes = writer.write( buf )
				buf.slice!( 0, bytes )
				bytes_copied += bytes
			end
		end

		return bytes_copied
	end


	### Given a Tempfile object open to uploaded gem data, move it into the
	### repo, post-process it, and return a Gem::Format object for it.
	def process_gem( tmpfile )

		# Make sure the file is a valid gem
		format = begin
			Gem::Format.from_file_by_path( tmpfile.path )
		rescue Gem::Exception => err
			$stderr.puts "Invalid gem uploaded: %s: %s" % [ err.class.name, err.message ]
			header 'Accept' => 'application/x-rubygem'
			throw :halt, [ 406, "Not acceptable" ]
		rescue => err
			$stderr.puts "Corrupted gem uploaded: %s: %s" % [ err.class.name, err.message ]
			throw :halt, [ 400, "Bad request" ]
		end

		# Figure out where it's going to be written
		name = format.spec.original_name + '.gem'
		$stderr.puts "Uploading gem: #{name.inspect}"
		gemname = Pathname( name ).basename
		gempath = self.options.gemsdir + 'gems' + gemname

		# If it's already there, refuse to replace it
		# if gempath.exist?
		# 	status 403
		# 	return "Forbidden: can't replace existing gem #{gemname}".dump
		# end

		# Write it to its final destination
		gempath.dirname.mkpath
		gempath.open( File::TRUNC|File::CREAT|File::WRONLY, 0644 ) do |gemfile|
			copy_io( tmpfile, gemfile )
		end

		# Re-build the indexes
		self.indexer.generate_index

		return format
	end


	### GET /
	get '/' do
		erb :index,
			:locals => {
				:config => self.options.config,
				:gemindex => self.indexer.collect_specs,
			}
	end

	### GET /gems -- render the gems table without the main layout
	get '/gems' do
		erb :index,
			:layout => false,
			:locals => {
				:config => self.options.config,
				:gemindex => self.indexer.collect_specs,
			}
	end


	### GET /details/<gemname>
	get '/details/:gemname' do |gemname|
		si         = self.indexer.collect_specs
		dependency = Gem::Dependency.new( gemname )
		gems       = si.search( dependency )

		erb :details,
			:locals => {
				:config     => self.options.config,
				:gemname    => gemname,
				:gems       => gems,
				:dependency => dependency,
			}
	end


	### POST /api/v1/gems
	### Support for 'gem push'
	post '/api/v1/gems' do
		# self.require_authentication

		$stderr.puts "Processing upload..."
		tmpfile = Tempfile.new( "uploaded_gem" )
		$stderr.puts "  buffering posted data to %p" % [ tmpfile.path ]
		bytes = copy_io( request.body, tmpfile )
		$stderr.puts "  done (%d Kb). Processing..." % [ bytes/1024 ]
		tmpfile.rewind
		format = process_gem( tmpfile )
		$stderr.puts "  processed: %s" % [ format.spec.original_name ]

		return "Accepted #{format.spec.original_name}.gem"
	end


	### GET /api/v1/api_key
	post '/api/v1/api_key' do
		self.require_authentication
		return "Great success!"
	end


	### Upload a gem
	post '/upload' do
		self.require_authentication
		tmpfile = nil

		# Check for an uploaded gem file in the query params
		unless params[:gem] && (tmpfile = params[:gem][:tempfile])
			status 400
			return "Bad request".dump
		end

		format = process_gem( tmpfile )

		content_type( 'application/javascript' )
		return YAML.load( format.spec.to_yaml ).to_json
	end


	get /\.(rz|Z)$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching deflated file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		content_type( 'application/x-deflate' )
		send_file( filepath )
	end

	get /\.#{Regexp.escape MARSHAL_VERSION}\.gz$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching gzip-compressed file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		content_type( 'application/x-gzip' )
		send_file( filepath )
	end

	get /(?:^yaml|\.(?:#{Regexp.escape MARSHAL_VERSION}|gem))$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching plain file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		send_file( filepath )
	end


end # class Gemserver::App

