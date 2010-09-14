#!/usr/bin/env rackup

require 'fileutils'
require 'pathname'
require 'gemserver/app'

basedir = Pathname( __FILE__ ).dirname
logfile = basedir + 'log/sinatra.log'

logfile.dirname.mkpath
log = logfile.open( 'a' )
# $stdout.reopen( log )
# $stderr.reopen( log )

Gemserver::App.set :configfile, basedir + 'config.yml'
run Gemserver::App

