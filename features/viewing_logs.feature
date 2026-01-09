Feature: Viewing Rails logs
  As a developer
  I want to view my Rails logs in a web interface
  So that I can understand what my application is doing

  Background:
    Given a Rails log file exists

  Scenario: Viewing the log viewer with no requests
    Given the log file is empty
    And I am on the trainspotter page
    Then I should see "No requests found"

  Scenario: Viewing a simple GET request
    Given the log file contains a GET request to "/posts"
    And I am on the trainspotter page
    Then I should see a request group for "GET /posts"
    And the request should show status "200"

  Scenario: Viewing request details
    Given the log file contains a GET request to "/posts" with SQL queries
    And I am on the trainspotter page
    When I expand the request group for "/posts"
    Then I should see the SQL queries within the request

  Scenario: Viewing multiple requests
    Given the log file contains:
      | method | path   | status |
      | GET    | /posts | 200    |
      | POST   | /posts | 302    |
      | GET    | /users | 404    |
    And I am on the trainspotter page
    Then I should see 3 request groups
    And I should see a request group for "GET /posts"
    And I should see a request group for "POST /posts"
    And I should see a request group for "GET /users"

  Scenario: Request groups are color-coded by status
    Given the log file contains:
      | method | path    | status |
      | GET    | /ok     | 200    |
      | GET    | /redir  | 302    |
      | GET    | /notfnd | 404    |
      | GET    | /error  | 500    |
    And I am on the trainspotter page
    Then the request for "/ok" should have class "success"
    And the request for "/redir" should have class "redirect"
    And the request for "/notfnd" should have class "client-error"
    And the request for "/error" should have class "server-error"
