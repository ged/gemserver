Feature: Web interface

	In order to save time while admining the gem server
	As a repository admin
	I want to be able to interact with the server through a web browser
	
	Scenario: an empty gem repository
		Given a gem repository with no gems in it
		When I fetch the index page
		Then I see a message describing the empty repository
			And instructions on how to upload a gem

	Scenario: a gem repository with 2 gems

	Scenario: a gem repository with 2 versions of the same gem

	Scenario: a gem repository with only a prerelease version of a gem

	Scenario: a gem repository with a prerelease version and a regular version of a gem
	


	
