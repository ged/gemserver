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

	before( :all ) do
		basedir = Pathname( __FILE__ ).dirname.parent.parent
		datadir = basedir + 'data/gemserver'
		configfile = datadir + 'gemserver.conf.example'
		@config = Configurability::Config.load( configfile )

		Gemserver::App.configure( @config.gemserver )
		setup_logging( :debug )
	end

	before( :each ) do
		@indexer = double( Gem::Indexer )
		Gem::Indexer.stub( :new ).and_return( @indexer )

		@app     = Gemserver::App.new
		@session = Rack::MockSession.new( @app )
		@browser = Rack::Test::Session.new( @session )
	end

	after( :all ) do
		reset_logging()
	end


	# Testing gem data
	GEMDATA = [
		{
			:name    => 'angel-ashweight',
			:version => Gem::Version.new( '1.2.3' ),
			:summary => 'I have two angels, | one red as rust | and the other white',
		},
		{
			:name    => 'fathoms',
			:version => Gem::Version.new( '0.1.4' ),
			:summary => 'There are fathoms unplumbed | in at least this, | my love',
		},
	]


	context "with no uploaded gems" do

		it "displays a message that indicates that no gems have been uploaded if the gem index " +
		   "is empty" do
			@indexer.should_receive( :collect_specs ).and_return( [] )

			@browser.header 'Accept', 'text/html'
		    @browser.get '/'

		    @browser.last_response.should be_ok()
		    @browser.last_response.body.should_not =~ /released gems/i
			@browser.last_response.body.should =~ /No gems are published/i
		end

	end


	context "with uploaded gem" do

		before( :each ) do
			@gemspec1 = stub( "first gemspec", GEMDATA[0] )
			@gemspec2 = stub( "second gemspec", GEMDATA[1] )
			@gemindex = stub( "Gem::Index" )

			@indexer.stub( :collect_specs ).and_return( @gemindex )
			@gemindex.stub( :length ).and_return( 2 )
			@gemindex.stub( :latest_specs ).and_return([ @gemspec1, @gemspec2 ])
		end

		it "displays them in a list on the index page" do
			@browser.header 'Accept', 'text/html'
		    @browser.get '/'

		    @browser.last_response.should be_ok()
			if RUBY_VERSION >= '1.9.0'
				@browser.last_response.content_type.should == 'text/html;charset=utf-8'
			else
				@browser.last_response.content_type.should == 'text/html'
			end
		    @browser.last_response.body.should =~ /released gems/i
			@browser.last_response.body.should include( GEMDATA[0][:name], GEMDATA[1][:name] )
			@browser.last_response.body.should include( GEMDATA[0][:version].to_s, GEMDATA[1][:version].to_s )
			@browser.last_response.body.should include( GEMDATA[0][:summary], GEMDATA[1][:summary] )
		end

		it "can render them in the index table as a partial" do
			@browser.header 'Accept', 'text/html'
		    @browser.get '/gems'

		    @browser.last_response.should be_ok()
			if RUBY_VERSION >= '1.9.0'
				@browser.last_response.content_type.should == 'text/html;charset=utf-8'
			else
				@browser.last_response.content_type.should == 'text/html'
			end
		    @browser.last_response.body.should_not =~ /<head>/i
		    @browser.last_response.body.should =~ /released gems/i
			@browser.last_response.body.should include( GEMDATA[0][:name], GEMDATA[1][:name] )
			@browser.last_response.body.should include( GEMDATA[0][:version].to_s, GEMDATA[1][:version].to_s )
			@browser.last_response.body.should include( GEMDATA[0][:summary], GEMDATA[1][:summary] )
		end

	end


end


# vim: set nosta noet ts=4 sw=4:
