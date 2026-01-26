@smoke
Feature: Todo batch operations
  As a user
  I want to add multiple todos efficiently
  So that I can quickly populate my list

  Background:
    Given the app is launched
    And the todo list is empty

  Scenario: Add todos from a data table
    When I add the following todos:
      | title            |
      | Buy groceries    |
      | Walk the dog     |
      | Read a book      |
      | Clean the house  |
    Then the item count should be 4
    And I should see "Buy groceries" at position 0
    And I should see "Walk the dog" at position 1
    And I should see "Read a book" at position 2
    And I should see "Clean the house" at position 3

  Scenario Outline: Add todo with specific text
    When I enter "<title>" in the text field
    And I tap the add button
    Then I should see "<title>" at position 0
    And the count label should read "<count_text>"

    Examples:
      | title          | count_text |
      | Morning run    | 1 item     |
      | Evening study  | 1 item     |

  Scenario: Add numbered todos
    When I add 3 todos with prefix "Task"
    Then the item count should be 3
    And I should see "Task 1" at position 0
    And I should see "Task 2" at position 1
    And I should see "Task 3" at position 2

  @wip
  Scenario: Drag to reorder todos
    When I add the following todos:
      | title       |
      | First item  |
      | Second item |
      | Third item  |
    Then I should see "First item" at position 0
    # Drag-and-drop reorder not yet implemented
