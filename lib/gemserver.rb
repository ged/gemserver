#!/usr/bin/env ruby

require 'rubygems'
require 'logger'
require 'rack'
require 'rack/builder'
require 'thin'
require 'sinatra'
require 'pathname'
require 'tmpdir'
require 'configurability'
require 'configurability/config'


# Gemserver namespace module
module Gemserver
	extend Configurability

	# Configurability API -- sets the section of the config that the module uses.
	config_key :rack


	# Software version
	VERSION = '0.2.0'

	# The path to the gemserver's data directory
	SYSTEM_DATADIR = Pathname( Gem.datadir('gemserver') || 'data/gemserver' )

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

	# The path to the directory that contains the gem data
	DEFAULT_GEMSDIR = Pathname( Dir.tmpdir ) + 'uploaded_gems'

	# The name of the config file
	CONFIGFILE_NAME = 'gemserver.conf'

	# The path to the example config
	EXAMPLE_CONFIG = Pathname( Gem.datadir('gemserver') || 'data/gemserver' ) +
		"#{CONFIGFILE_NAME}.example"

	# Configuration defaults
	CONFIG_DEFAULTS = {
		:loglevel  => :info,
		:rack      => {
			:host     => DEFAULT_HOST,
			:port     => DEFAULT_PORT,
			:env      => DEFAULT_RACK_ENV,
		},
		:gemserver => {
			:name     => nil, # Defaults to the hostname
			:gemsdir  => DEFAULT_GEMSDIR,
			:ldapuri  => nil, # Use ldap.conf values
		}
	}

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
	@default_logger.level = ($DEBUG||$VERBOSE) ? Logger::DEBUG : Logger::WARN

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
	require 'gemserver/mixins'
	require 'gemserver/keystore'


	### Load the configuration and install it
	def self::load_config( *args )
		configfile = args.flatten.shift || self.find_standard_config

		if configfile
			self.log.info "Loading config from: %s" % [ configfile ]
			return Configurability::Config.load( configfile, CONFIG_DEFAULTS )
		else
			self.log.warn "No configfile; using defaults."
			return Configurability::Config.new( nil, nil, CONFIG_DEFAULTS )
		end
	end


	### Find the config file in a standard path and return it.
	### @return [Pathname] the path to the config, or nil if it wasn't in any of the 
	### standard places.
	def self::find_standard_config
		self.log.debug "Looking for a standard config."
		bindir  = Pathname( $0 ).dirname
		basedir = bindir.parent
		etcdir  = basedir + 'etc'

		# Try both ./config.yml and the etc/ directory that's in the same hierarchy as the
		# binary being run (/usr/local/bin/gemserver -> /usr/local/etc/gemserver.conf)
		appconfig    = Pathname.pwd + CONFIGFILE_NAME
		globalconfig = etcdir  + CONFIGFILE_NAME

		return appconfig if appconfig.exist?
		self.log.debug "  not in #{appconfig}..."
		return globalconfig if globalconfig.exist?
		self.log.debug "  not in #{globalconfig}; giving up."

		return nil
	end


	### Configure the rack server values if the config has a 'rack' section.
	def self::configure( config )
		self.host = config.host if config.host
	  	self.port = config.port if config.port
	  	self.env  = config.env  if config.env
	end


	### Start the gemserver, parsing the command line options from +args+.
	def self::start( config )
		# Squelch some warnings about undefined instance variables
		Thin::Logging.silent = false
		Thin::Logging.trace = false

		# Combine all the loggers
		Configurability.logger = self.logger
		Treequel.logger = self.logger
		if config.respond_to?( :loglevel )
			level = LOG_LEVELS[ config.loglevel.to_s ] or
				raise "unknown loglevel %p" % [ config.loglevel ]
			self.logger.level = level
			self.log.debug "Logging level set to: %s" % [ config.loglevel ]
		end

		# Propagate the configuration to any objects that have configurability
		Configurability.configure_objects( config )

		# Start the server
        Thin::Server.start( self.host, self.port ) do
			use Rack::Chunked
			use Rack::ContentLength
			use Rack::ShowExceptions if Gemserver.env == 'development'
			use Rack::Lint if Gemserver.env == 'development'

			run Gemserver::App
		end
	end

end # module Gemserver

