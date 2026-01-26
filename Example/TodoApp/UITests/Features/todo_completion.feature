Feature: Todo completion
  As a user
  I want to mark todos as complete or incomplete
  So that I can track my progress

  Background:
    Given the app is launched
    And the todo list is empty

  Scenario: Mark a todo as complete
    When I enter "Buy groceries" in the text field
    And I tap the add button
    And I toggle the todo at position 0
    Then the todo at position 0 should be completed

  Scenario: Mark a completed todo as incomplete
    When I enter "Buy groceries" in the text field
    And I tap the add button
    And I toggle the todo at position 0
    Then the todo at position 0 should be completed
    When I toggle the todo at position 0
    Then the todo at position 0 should not be completed

  Scenario: Complete one of many todos
    When I enter "Buy groceries" in the text field
    And I tap the add button
    And I enter "Walk the dog" in the text field
    And I tap the add button
    And I enter "Read a book" in the text field
    And I tap the add button
    And I toggle the todo at position 1
    Then the todo at position 0 should not be completed
    And the todo at position 1 should be completed
    And the todo at position 2 should not be completed
