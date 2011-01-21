#!/usr/bin/env ruby

require 'pathname'
require 'sequel'
require 'digest/sha1'

require 'gemserver' unless defined?( Gemserver )


# A simple store for API keys
class Gemserver::Keystore

	# The name of the database file to store keys in
	DBFILE_NAME = 'gemserver.db'

	# The name of the API keys table
	KEYTABLE = :apikeys

	### Create or load the keystore in the given +datadir+.
	def initialize( datadir=Gemserver::DEFAULT_GEMSDIR )
		datadir = Pathname( datadir )
		dbfile = datadir + DBFILE_NAME
		@db = Sequel.sqlite( dbfile.to_s )
		self.install_schema unless @db.table_exists?( :apikeys )

		@keytable = @db[ KEYTABLE ]
	end


	######
	public
	######

	### Get the apikey for the user with the specified +username+.
	def get_apikey( username )
		result = @keytable.filter( :user => username ).select( :apikey ).first
		return result ? result[ :apikey ] : nil
	end


	### Create a new API key for the user with the specified +username+ and +password+ and
	### return it.
	def make_apikey( username, password )
		apikey = make_token( username, password )
		@keytable.insert( :user => username, :apikey => apikey, :created_at => Time.now )

		return apikey
	end


	### Delete the apikey associated with the given +username+.
	def delete_apikey( username )
		@keytable.delete( :user => username )
	end


	### Returns +true+ if the given +apikey+ exists.
	def apikey_exists?( apikey )
		return false if @keytable.filter( :apikey => apikey ).empty?
		return true
	end



	#########
	protected
	#########

	### Install the schema in a new database.
	def install_schema
		@db.create_table( KEYTABLE ) do
			primary_key :id
			String :user
			String :apikey
			Time :created_at
		end
	end


	#######
	private
	#######

	### Validate the given +token+ with the specified +username+ and +password+.
	def validate_token( token, username, password )
		salt = token.unpack( 'm' ).first[ -10..-1 ]
		remade_token = make_token( username, password, salt )

		return token == remade_token
	end


	### Hash the specified password using salted-SHA1
	def make_token( username, password, salt=nil )
		salt  ||= Array.new( 5 ) { rand(256) }.pack( 'C*' ).unpack( 'H*' ).first
		return [ Digest::SHA1.digest(username + '__' + password + '__' + salt) + salt ].pack( 'm' ).chomp
	end

end # module Gemserver::Keystore


