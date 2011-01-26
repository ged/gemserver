#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'rack/test'

require 'spec/lib/helpers'

require 'configurability/config'
require 'pathname'
require 'tmpdir'

require 'gemserver/app'


# Set up Sinatra to cooperate with the test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :show_exceptions, false
set :logging, true

RSpec.configure do |config|
	config.include( Rack::Test::Methods )
end

#####################################################################
###	C O N T E X T S
#####################################################################

describe Gemserver::App do

end


# vim: set nosta noet ts=4 sw=4:
