Feature: Selecting log files
  As a developer
  I want to select which log file to view
  So that I can view logs from different environments

  Scenario: Default log file is the current environment
    Given the following log files exist:
      | filename        |
      | development.log |
      | test.log        |
      | production.log  |
    When I visit the trainspotter page
    Then the log selector should show "test.log" as selected

  Scenario: Viewing available log files
    Given the following log files exist:
      | filename        |
      | development.log |
      | test.log        |
      | production.log  |
    When I visit the trainspotter page
    Then I should see "development.log" in the log selector
    And I should see "test.log" in the log selector
    And I should see "production.log" in the log selector

  @javascript
  Scenario: Switching to a different log file
    Given the following log files exist:
      | filename        |
      | development.log |
      | test.log        |
    And "development.log" contains a GET request to "/dev-endpoint"
    And "test.log" contains a GET request to "/test-endpoint"
    When I visit the trainspotter page
    Then I should see a request group for "GET /test-endpoint"
    When I select "development.log" from the log selector
    Then I should see a request group for "GET /dev-endpoint"
    And I should not see "/test-endpoint"

  Scenario: Only .log files are shown
    Given the following log files exist:
      | filename        |
      | development.log |
      | test.log        |
      | some_other.txt  |
      | debug.log       |
    When I visit the trainspotter page
    Then I should see "development.log" in the log selector
    And I should see "test.log" in the log selector
    And I should see "debug.log" in the log selector
    And I should not see "some_other.txt" in the log selector
