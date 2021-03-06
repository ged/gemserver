#!/usr/bin/env ruby

require 'treequel'
require 'rack/auth/basic'

require 'gemserver' unless defined?( Gemserver )
require 'gemserver/mixins'


# HTTP basic authentication wrapper for Sinatra, stolen and reworked
# a little from:
#    http://www.gittr.com/index.php/archive/sinatra-basic-authentication-selectively-applied/
module Gemserver::Authentication
	include Gemserver::Loggable

	### Wrap the request in a basic authentication adapter.
	def auth
		@auth ||= Rack::Auth::Basic::Request.new( request.env )
	end


	### Return the configured Treequel::Directory for authentication.
	def ldap
		if !@ldap
			if self.options.config && (uri = self.options.config.ldapuri)
				@ldap = Treequel.directory( uri )
			else
				@ldap = Treequel.directory_from_config
			end

			self.log.info "Authentication will use: %s" % [ @ldap.uri ]
		end

		return @ldap
	end


	### Halt the current request and respond with a 401 AUTHORIZATION REQUIRED
	def send_authrequired_response( realm="gemserver" )
		self.response['WWW-Authenticate'] = %(Basic realm="#{realm}")
		throw :halt, [ 401, 'Authorization required' ]
	end


	### Halt the current request and respond with a 400 BAD REQUEST
	def send_bad_request_response
		throw :halt, [ 400, 'Bad Request' ]
	end


	### Returns true if the current response has provided valid authentication.
	def authenticated?
		return self.request.env['REMOTE_USER'] ? true : false
	end


	### Returns true if the given +username+ and +password+ are valid 
	### authentication.
	def authenticate( authuser, password )
		unless username = self.validate_username( authuser )
			self.log.error "Invalid username %p" % [ authuser ]
			return false
		end

		user = self.ldap.base.
			filter( :objectClass => :posixAccount ).
			filter( :uid => username ).first

		unless user
			self.log.error "Authentication failed: no such user %p" % [ username ]
			return false
		end

		self.ldap.bind( user, password ) # raises LDAP::ResultError if it fails
		self.log.info "Authenticated %p (%s)" % [ username, user.dn ]

		return true

	rescue LDAP::ResultError => err
		self.log.error "  authentication failed for %p (%p: %s)" %
			[ user || username, err.class, err.message ]
		return false
	end


	### Return an untainted copy of the given +username+ if it's valid, else 
	### return +nil+.
	def validate_username( username )
		if username =~ /^([a-z]\w+)$/i
			return $1.untaint.downcase
		else
			return nil
		end
	end


	### Check for authentication and respond with an appropriate error status 
	### if authentication hasn't been provided.
	def require_authentication
		authrequest = self.auth

		return if self.authenticated?
		return self.send_authrequired_response unless authrequest.provided?
		return self.send_bad_request_response unless authrequest.basic?
		return self.send_authrequired_response unless self.authenticate( *authrequest.credentials )

		request.env['REMOTE_USER'] = authrequest.username
	end

end # module Gemserver::Authentication
