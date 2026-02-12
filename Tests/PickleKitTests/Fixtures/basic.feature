Feature: Basic arithmetic
  Verifies basic arithmetic operations produce correct results.

  Scenario: Addition
    Given I have the number 5
    When I add 3
    Then the result should be 8

  Scenario: Subtraction
    Given I have the number 10
    When I subtract 4
    Then the result should be 6
