Feature: Viewing user sessions
  As a developer
  I want to view user sessions grouped by login
  So that I can understand user activity patterns

  Background:
    Given a Rails log file exists

  Scenario: Viewing the sessions page with no sessions
    Given the log file is empty
    And I am on the trainspotter page
    When I follow "Sessions"
    Then I should see "No sessions found"

  Scenario: Viewing a session with a logged-in user
    Given the log file contains a login request for "alice@example.com" from "192.168.1.1"
    And the log file contains a GET request to "/dashboard" from "192.168.1.1"
    And I am on the trainspotter page
    When I follow "Sessions"
    Then I should see "alice@example.com"
    And I should see "192.168.1.1"
    And I should see "2 req"

  Scenario: Anonymous sessions are hidden by default
    Given the log file contains a GET request to "/posts" from "192.168.1.2"
    And I am on the trainspotter page
    When I follow "Sessions"
    Then I should not see "192.168.1.2"

  Scenario: Showing anonymous sessions
    Given the log file contains a GET request to "/posts" from "192.168.1.2"
    And I am on the trainspotter page
    When I follow "Sessions"
    And I check "Show anonymous"
    Then I should see "Anonymous"
    And I should see "192.168.1.2"

  Scenario: Expanding a session to view requests
    Given the log file contains a login request for "bob@example.com" from "10.0.0.1"
    And the log file contains a GET request to "/profile" from "10.0.0.1"
    And I am on the trainspotter page
    When I follow "Sessions"
    And I expand the session for "bob@example.com"
    Then I should see a request for "GET /profile"

  Scenario: Session ends on logout
    Given the log file contains a login request for "charlie@example.com" from "172.16.0.1"
    And the log file contains a GET request to "/settings" from "172.16.0.1"
    And the log file contains a logout request from "172.16.0.1"
    And I am on the trainspotter page
    When I follow "Sessions"
    Then I should see "charlie@example.com"
    And I should see "Logout"

  Scenario: Session timeout creates new session
    Given the log file contains a login request for "dave@example.com" from "10.0.0.5" at "2024-01-06 10:00:00"
    And the log file contains a GET request to "/page1" from "10.0.0.5" at "2024-01-06 10:05:00"
    And the log file contains a GET request to "/page2" from "10.0.0.5" at "2024-01-06 11:00:00"
    And I am on the trainspotter page
    When I follow "Sessions"
    And I check "Show anonymous"
    Then I should see 2 sessions

  Scenario: Multiple users have separate sessions
    Given the log file contains a login request for "user1@example.com" from "192.168.1.10"
    And the log file contains a login request for "user2@example.com" from "192.168.1.20"
    And I am on the trainspotter page
    When I follow "Sessions"
    Then I should see "user1@example.com"
    And I should see "user2@example.com"

  Scenario: Navigation between requests and sessions
    Given the log file contains a GET request to "/posts" from "127.0.0.1"
    And I am on the trainspotter page
    Then I should see a link to "Sessions"
    When I follow "Sessions"
    Then I should see a link to "Requests"
