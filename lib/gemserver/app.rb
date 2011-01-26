#!/usr/bin/env ruby

require 'pathname'
require 'rbconfig'
require 'erb'
require 'json'
require 'yaml'
require 'socket'

require 'rubygems'
require 'rubygems/indexer'

require 'sinatra/base'

require 'configurability'

require 'gemserver'
require 'gemserver/authentication'
require 'gemserver/mixins'
require 'gemserver/keystore'


include ERB::Util

class Gemserver::App < Sinatra::Base
	extend Configurability
	include Gemserver::Authentication,
	        Gemserver::Loggable

	# Configurability API -- register for the 'gemserver' section of the config
	config_key :gemserver

	# Sinatra API -- add some Rack middleware
	enable :sessions, :static, :logging, :dump_errors


	# The size of the read buffer when doing IO->IO copies
	READ_CHUNKSIZE = 65536


	### Return a Pathname to the application's data directory. If it's installed, this will
	### be a subdirectory of the installed datadir; if it's being run in-place, it will be
	### derived from a relative path from this file.
	def self::root
		if Gemserver::SYSTEM_DATADIR.exist?
			return Gemserver::SYSTEM_DATADIR.to_s
		else
			return Pathname( __FILE__ ).dirname.parent.parent + 'data/gemserver'
		end
	end


	### Return the application config.
	def self::configure( config )
		set :config, config

		gemsdir = config.respond_to?( :gemsdir ) ?
			Pathname( config.gemsdir.to_s ) :
			Gemserver::DEFAULT_GEMSDIR
		set :gemsdir, gemsdir
	end


	#################################################################
	###	A C T I O N S
	#################################################################

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
		self.log.info "Gem push: "

		# Get the token, or respond with a 401 if there isn't one
		apikey = self.env['HTTP_AUTHORIZATION']
		unless apikey && self.keystore.apikey_exists?( apikey )
			self.log.error "Bad/missing API key: %p" % [ apikey ]
			self.response['WWW-Authenticate'] = %(apikey realm="gemserver")
			throw :halt, [ 401, 'Authorization required' ]
		end

		self.log.info "Accepted API key."
		io = request.body
		# io = request.body.instance_variable_get( :@input )
		# $stderr.puts "  unwrapped the IO from the half-assed rack wrapper: %p" % [ io ]
		gemspec = handle_gem_upload( io )

		content_type( 'text/plain' )
		return "Registered %s v%s." % [ gemspec.name, gemspec.version ]
	end


	### GET /api/v1/api_key
	get '/api/v1/api_key' do
		self.require_authentication

		username, password = self.auth.credentials
		apikey = self.keystore.get_apikey( username ) || 
		         self.keystore.make_apikey( username, password )

		return apikey
	end


	### Upload a gem
	post '/upload' do
		self.log.info "Gem upload: "
		self.require_authentication
		tmpfile = name = nil

		# Check for an uploaded gem file in the query params
		unless params[:gem] &&
			(tmpfile = params[:gem][:tempfile]) &&
			(name    = params[:gem][:filename])

			self.log.error "Upload with no 'gem' field."
			status 400
			return "Bad request".dump
		end

		gemspec = handle_gem_upload( tmpfile )

		content_type( 'application/javascript' )
		return YAML.load( gemspec.to_yaml ).to_json
	end


	### Rubygems index files
	get /\.(rz|Z)$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching deflated file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		content_type( 'application/x-deflate' )
		send_file( filepath )
	end

	get /\.#{Regexp.escape Gemserver::MARSHAL_VERSION}\.gz$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching gzip-compressed file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		content_type( 'application/x-gzip' )
		send_file( filepath )
	end

	get /(?:^yaml|\.(?:#{Regexp.escape Gemserver::MARSHAL_VERSION}|gem))$/ do
		filepath = self.options.gemsdir + self.request.path_info[1..-1]
		$stderr.puts "Fetching plain file %p for path_info: %p..." %
			[ filepath, self.request.path_info ]
		send_file( filepath )
	end


	#########
	protected
	#########

	### Fetch the Rubygems indexer, creating it if necessary
	def indexer
		@indexer ||= Gem::Indexer.new( self.options.gemsdir )
	end


	### Fetch the Gemserver's keystore object, creating it if necessary
	def keystore
		@keystore ||= Gemserver::Keystore.new( self.options.gemsdir )
	end


	### Read a gem from the given +io+, install it into the gem datadir, and rebuild
	### the index. Return the Gem::Specification from the uploaded gem.
	def handle_gem_upload( io )
		pkg = nil

		# Make sure the file is a valid gem
		if io.respond_to?( :string )
			self.log.debug "Reading gem from memory"
			pkg = Gem::Format.from_io( io )
			io = StringIO.new( io.string )
		else
			self.log.debug "Reading gem from tmpfile: %s" % [ io.path ]
			pkg = Gem::Format.from_file_by_path( io.path )
		end

		# Figure out where it's going to be written
		self.log.info "Handling upload for gem: %s (v%s)" % [ pkg.spec.name, pkg.spec.version ]
		gemname = "%s-%s.gem" % [ pkg.spec.name, pkg.spec.version ]
		gempath = self.options.gemsdir + 'gems' + gemname

		# If it's already there, refuse to replace it
		throw :halt, [403, "Forbidden: can't replace existing gem #{gemname}"] if gempath.exist?

		# Write it to its final destination
		totalbytes = 0
		gempath.dirname.mkpath
		gempath.open( File::EXCL|File::CREAT|File::WRONLY, 0644 ) do |gemfile|
			totalbytes = copy_io( io, gemfile )
		end
		self.log.debug "  done writing (%s)." % [ byte_suffix(totalbytes) ]
		self.log.debug "  gem says it's: %s" % [ byte_suffix(gempath.size) ]

		# Re-build the indexes
		self.indexer.generate_index

		return pkg.spec
	rescue => err
		self.log.error "Corrupted gem uploaded: %s: %s" % [ err.class.name, err.message ]
		self.log.debug "  " + err.backtrace.join( "\n  " )
		throw :halt, [400, "Bad request"]
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


	### Add some prettification functions for views
	helpers do

		# Approximate Time Constants (in seconds)
		MINUTES = 60
		HOURS   = 60  * MINUTES
		DAYS    = 24  * HOURS
		WEEKS   = 7   * DAYS
		MONTHS  = 30  * DAYS
		YEARS   = 365.25 * DAYS


		### Return a string describing the amount of time in the given number of
		### seconds in terms a human can understand easily.
		def time_delta_string( start_time )
			seconds = 0
			if start_time.is_a?( Time )
				seconds = Time.now - start_time
			else
				start = Time.parse( start_time ) or return "some time"
				seconds = Time.now - start
			end

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


		# Byte size constants
		KILOBYTE = 1024
		MEGABYTE = 1024 ** 2
		GIGABYTE = 1024 ** 3

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

	end

end # class Gemserver::App

