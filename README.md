# gemserver

* https://bitbucket.org/ged/gemserver

## Description

This is an experimental minimalist Rubygems index and gem server for deploying private gems.

It authenticates against an LDAP server, but it should be fairly easy to replace the authentication bits with something different.

Some notable features:

* Serves gems and gem indexes, just like rubygems.org
* Supports uploading via 'gem push'
* Integrates with your LDAP directory for authentication
* Spiffy web interface which supports drag-and-drop, multi-file uploads for 
  modern browsers, and degrades into a simpler upload form for older browsers.

Caveats:

* Not designed or tested in high-traffic situations
* Not super-configurable; assumes you have an environment similar to ours or 
  are willing to hack it a bit


## Installation

    gem install gemserver


## Running It

The gem installs a 'gemserver' binary, which can be run out of the box with no
configuration to test out the software, provided the machine it's running on
has LDAP authentication configured correctly. It runs on all interfaces on
port 9292, stores its gems under a temporary directory, and keeps an in-memory
authtoken database.

Should you wish to run it in a permanent fashion, you'll want to create a
`gemserver.conf` file in the directory you wish to run it from that allows
customization of what interface and port it listens to, where it keeps its
gems and authentication tokens, etc. An example config is distributed with the
gem.

## Contributing

You can check out the current development source with Mercurial [from BitBucket][bitbucket], or if you prefer Git, via [its Github mirror][github].

After checking out the source, run:

	$ rake newb

This task will install any missing dependencies, run the tests/specs, and
generate the API documentation.


## License

Copyright (c) 2010, 2011, Michael Granger
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the author/s, nor the names of the project's
  contributors may be used to endorse or promote products derived from this
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


[bitbucket]: https://bitbucket.org/ged/gemserver
[github]: https://github.com/ged/gemserver

