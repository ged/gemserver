#!/usr/bin/env ruby


require 'pathname'
require 'rbconfig/datadir'
require 'erb'
require 'json'
require 'yaml'
require 'socket'

require 'rubygems'
require 'rubygems/indexer'

require 'sinatra/base'

require 'gemserver'


include ERB::Util

class Gemserver::App < Sinatra::Base
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
			if configfile
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
			start = Time.parse( start_time ) or return "some time"
			seconds = Time.now - start

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


	### GET /
	get '/' do
		indexer = Gem::Indexer.new( self.options.gemsdir )

		erb :index,
			:locals => {
				:gemindex => indexer.collect_specs,
			}
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

