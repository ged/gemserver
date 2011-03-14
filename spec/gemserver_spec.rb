#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
require 'gemserver'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Gemserver do

	before( :each ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

	it "propagates the loaded configuration" do
		Configurability::Config.should_receive( :load ).
			with( '/a/path/to/gemserver.conf', Gemserver::CONFIG_DEFAULTS ).
			and_return( :the_config )
		Gemserver.load_config( '/a/path/to/gemserver.conf' ).should == :the_config
	end


	it "has reasonable defaults" do
		argv = []
		Gemserver.stub!( :find_standard_config ).and_return( nil )
		config = Gemserver.load_config( argv )
		config.loglevel.should == :info
		config.rack.host.should == Gemserver::DEFAULT_HOST
		config.rack.port.should == Gemserver::DEFAULT_PORT
		config.rack.env.should == Gemserver::DEFAULT_RACK_ENV
	end

	it "runs the Gemserver::App as a Rack application when started" do
		Thin::Server.should_receive( :start ).
			with( Gemserver::DEFAULT_HOST, Gemserver::DEFAULT_PORT )

		config = Gemserver.load_config
		Gemserver.start( config )
	end

end


# vim: set nosta noet ts=4 sw=4:
