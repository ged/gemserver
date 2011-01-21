#!/usr/bin/env ruby

require 'rubygems'

# Gemserver namespace module
module Gemserver

	# Software version
	VERSION = '0.2.0'

	# The path to the gemserver's data directory
	SYSTEM_DATADIR = Pathname( Gem.datadir('gemserver') )

	# The path to the directory that contains the gem data
	DEFAULT_GEMSDIR = SYSTEM_DATADIR + 'gems'

	# The name of the regular gems index
	RELEASE_GEM_INDEXFILE = "specs.%s.gz" % [ Gem.marshal_version ]

	# The name of the prerelease gems index
	PRERELEASE_GEM_INDEXFILE = "prerelease_specs.%s.gz" % [ Gem.marshal_version ]

	# The Marshal version of the current system
	MARSHAL_VERSION = Gem.marshal_version


	require 'gemserver/app'
	require 'gemserver/authentication'
	require 'gemserver/keystore'

end # module Gemserver

