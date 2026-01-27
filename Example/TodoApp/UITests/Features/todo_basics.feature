@smoke
Feature: Todo basics
  As a user
  I want to manage my todo list
  So that I can keep track of tasks

  Background:
    Given the app is launched
    And the todo list is empty

  Scenario: Empty state message
    Then I should see the empty state message

  Scenario: Add a single todo
    When I enter "Buy groceries" in the text field
    And I tap the add button
    Then I should see "Buy groceries" at position 0
    And the item count should be 1

  Scenario: Add multiple todos
    When I enter "Buy groceries" in the text field
    And I tap the add button
    And I enter "Walk the dog" in the text field
    And I tap the add button
    And I enter "Read a book" in the text field
    And I tap the add button
    Then the item count should be 3
    And I should see "Buy groceries" at position 0
    And I should see "Walk the dog" at position 1
    And I should see "Read a book" at position 2

  Scenario: Delete a todo
    When I enter "Buy groceries" in the text field
    And I tap the add button
    And I enter "Walk the dog" in the text field
    And I tap the add button
    Then the item count should be 2
    When I delete the todo at position 0
    Then the item count should be 1
    And I should see "Walk the dog" at position 0

  Scenario: Cannot add empty todo
    Then the add button should be disabled
    When I enter "   " in the text field
    Then the add button should be disabled

  Scenario Outline: Edit a todo
    Given I have the following todos in my list:
      | title                    |
      | Buy organic groceries    |
      | Walk the dog for an hour |
    When I update the todo at position <index> to "<updated_value>"
    Then I should see "<updated_value>" at position <index>
    And the item count should be 2

    Examples:
      | index | updated_value            |
      | 0     | Walk the dog for an hour |
      | 1     | Read a book              |
