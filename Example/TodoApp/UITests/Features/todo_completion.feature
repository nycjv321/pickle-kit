Feature: Todo completion
  Covers toggling todo items between complete and incomplete states.

  Background:
    Given the app is launched
    And the todo list is empty

  Scenario: Mark a todo as complete
    Given I have the following todos in my list:
      | title         |
      | Buy groceries |
    When I toggle the todo at position 0
    Then the todo at position 0 should be completed

  Scenario: Mark a completed todo as incomplete
    Given I have the following todos in my list:
      | title         |
      | Buy groceries |
    When I toggle the todo at position 0
    Then the todo at position 0 should be completed
    When I toggle the todo at position 0
    Then the todo at position 0 should not be completed

  Scenario: Complete one of many todos
    Given I have the following todos in my list:
      | title         |
      | Buy groceries |
      | Walk the dog  |
      | Read a book   |
    When I toggle the todo at position 1
    Then the todo at position 0 should not be completed
    And the todo at position 1 should be completed
    And the todo at position 2 should not be completed
