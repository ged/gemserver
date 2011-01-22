#!/usr/bin/env ruby

require 'rubygems'
require 'logger'
require 'rack'
require 'rack/builder'
require 'thin'
require 'sinatra'
require 'pathname'
require 'configurability'
require 'configurability/config'


# Gemserver namespace module
module Gemserver
	extend Configurability

	config_key :rack

	# Software version
	VERSION = '0.2.0'

	# The path to the gemserver's data directory
	SYSTEM_DATADIR = Pathname( Gem.datadir('gemserver') || 'data/gemserver' )

	# The path to the directory that contains the gem data
	DEFAULT_GEMSDIR = SYSTEM_DATADIR + 'gems'

	# The name of the regular gems index
	RELEASE_GEM_INDEXFILE = "specs.%s.gz" % [ Gem.marshal_version ]

	# The name of the prerelease gems index
	PRERELEASE_GEM_INDEXFILE = "prerelease_specs.%s.gz" % [ Gem.marshal_version ]

	# The Marshal version of the current system
	MARSHAL_VERSION = Gem.marshal_version

	# The default address to listen on
	DEFAULT_HOST = '0.0.0.0'

	# The default listen port
	DEFAULT_PORT = 9292

	# The default Rack environment
	DEFAULT_RACK_ENV = 'development'

	# The name of the config file
	CONFIGFILE_NAME = 'gemserver.conf'

	# Map log level names
	LOG_LEVELS = {
		'debug' => Logger::DEBUG,
		'info'  => Logger::INFO,
		'warn'  => Logger::WARN,
		'error' => Logger::ERROR,
		'fatal' => Logger::FATAL,
	}.freeze
	LOG_LEVEL_NAMES = LOG_LEVELS.invert.freeze


	# Rack configuration values
	@host = DEFAULT_HOST
	@port = DEFAULT_PORT
	@env  = DEFAULT_RACK_ENV

	### Logging
	@default_logger = Logger.new( $stderr )
	@default_logger.level = $DEBUG ? Logger::DEBUG : Logger::WARN

	@logger = @default_logger

	class << self

		# Rack configuration values
		attr_accessor :host, :port, :env

		# @return [Logger] the logger that will be used when the logging subsystem is reset
		attr_accessor :default_logger

		# @return [Logger] the logger that's currently in effect
		attr_accessor :logger
		alias_method :log, :logger
		alias_method :log=, :logger=

	end


	### Reset the Gemserver logger object back to defaults
	def self::reset_logger
		self.logger = self.default_logger
		self.logger.level = Logger::WARN
	end


	require 'gemserver/app'
	require 'gemserver/authentication'
	require 'gemserver/keystore'


	### Load the configuration and install it
	def self::load_config( args )
		bindir  = Pathname( $0 ).dirname
		basedir = bindir.parent
		etcdir  = basedir + 'etc'

		# Try both ./config.yml and the etc/ directory that's in the same hierarchy as the
		# binary being run (/usr/local/bin/gemserver -> /usr/local/etc/gemserver.conf)
		appconfig    = Pathname.pwd + CONFIGFILE_NAME
		globalconfig = etcdir  + CONFIGFILE_NAME

		# Try to find the config in:
		#   ARGV[0]
		#   ./gemserver.conf
		#   (etcdir)/gemserver.conf
		# Fall back to an empty config if none of those are found.
		config = nil
		if ! args.empty?
			configfile = args.shift
			config = Configurability::Config.load( configfile )
		elsif appconfig.exist?
			config = Configurability::Config.load( appconfig )
		elsif globalconfig.exist?
			config = Configurability::Config.load( globalconfig )
		else
			$stderr.puts "Couldn't find a config file! Using defaults."
			config = Configurability::Config.new
		end

		return config
	end


	### Configure the rack server values if the config has a 'rack' section.
	def self::configure( config )
		self.host = config.host if config.host
	  	self.port = config.port if config.port
	  	self.env  = config.env  if config.env
	end


	### Start the gemserver, parsing the command line options from +args+.
	def self::start( args )
		config = self.load_config( args )

		# Combine all the loggers
		Configurability.logger = self.logger
		Treequel.logger = self.logger
		if config.loglevel && level = LOG_LEVELS[ config.loglevel ]
			self.logger.level = level
			self.log.debug "Logging level set to: %s" % [ config.loglevel ]
		end

		# Propagate the configuration to any objects that have configurability
		Configurability.configure_objects( config )

        Thin::Server.start( self.host, self.port ) do
			use Rack::Chunked
			use Rack::ContentLength
			use Rack::CommonLogger, $stderr if
				Gemserver.env == 'development' || Gemserver.env == 'production'
			use Rack::ShowExceptions if Gemserver.env == 'development'
			use Rack::Lint if Gemserver.env == 'development'

			run Gemserver::App
		end
	end


end # module Gemserver

