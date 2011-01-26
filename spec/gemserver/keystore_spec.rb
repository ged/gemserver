#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'

require 'tmpdir'

require 'gemserver'
require 'gemserver/keystore'


#####################################################################
###	C O N T E X T S
#####################################################################

describe Gemserver::Keystore do

	before( :all ) do
		setup_logging( :fatal )
		@datadir = Pathname( Dir.tmpdir )
		@dbfile = @datadir + Gemserver::Keystore::DBFILE_NAME
	end

	after( :each ) do
		@dbfile.delete if @dbfile.exist?
	end

	after( :all ) do
		reset_logging()
	end


	TEST_USERNAME = 'jrandom'
	TEST_PASSWORD = 'noodu6Ooqueubae3'

	it "uses an in-memory database if created without a data directory" do
		Gemserver::Keystore.new.db.url.should == 'sqlite:/'
	end


	it "creates a new database in the data directory if one is specified" do
		Gemserver::Keystore.new( @datadir ).db.url.
			should == "sqlite:/#{@dbfile}"
	end


	it "re-uses an existing database in the data directory if given one and there's " +
	   "already a database there" do
		ks = Gemserver::Keystore.new( @datadir )
		key = ks.make_apikey( TEST_USERNAME, TEST_PASSWORD )
		ks = Gemserver::Keystore.new( @datadir )
		ks.apikey_exists?( key ).should be_true()
	end


	context	"an instance" do

		before( :each ) do
			@keystore = Gemserver::Keystore.new( @datadir )
		end


		it "can generate a secure API key" do
			key = @keystore.make_apikey( TEST_USERNAME, TEST_PASSWORD )
			key.should =~ /^\w{40}$/
		end
	end

end


# vim: set nosta noet ts=4 sw=4:
