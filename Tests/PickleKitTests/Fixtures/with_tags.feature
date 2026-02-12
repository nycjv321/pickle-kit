@smoke
Feature: Tagged scenarios
  Verifies feature-level and scenario-level tags are parsed correctly.

  @fast
  Scenario: Quick check
    Given I have a system
    Then it should respond

  @slow @integration
  Scenario: Full integration
    Given I have a complex system
    When I run the full suite
    Then all checks should pass

  @wip
  Scenario: Work in progress
    Given I have a new feature
    Then it should be incomplete
