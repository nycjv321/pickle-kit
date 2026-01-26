Feature: Data tables

  Scenario: User list
    Given the following users exist:
      | name    | email             | role  |
      | Alice   | alice@example.com | admin |
      | Bob     | bob@example.com   | user  |
      | Charlie | charlie@test.com  | user  |
    When I search for users with role "admin"
    Then I should find 1 user
