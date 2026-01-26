Feature: Shopping cart
  Background:
    Given I have an empty cart
    And I am logged in as "testuser"

  Scenario: Add single item
    When I add "Apple" to the cart
    Then the cart should contain 1 item

  Scenario: Add multiple items
    When I add "Apple" to the cart
    And I add "Banana" to the cart
    Then the cart should contain 2 items
