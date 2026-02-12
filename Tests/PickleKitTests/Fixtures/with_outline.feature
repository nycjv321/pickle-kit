Feature: Outline examples
  Verifies outline expansion substitutes example values into step templates.

  Scenario Outline: Eating fruits
    Given I have <start> fruits
    When I eat <eaten> fruits
    Then I should have <remaining> fruits

    Examples:
      | start | eaten | remaining |
      | 12    | 5     | 7         |
      | 20    | 5     | 15        |

    Examples:
      | start | eaten | remaining |
      | 8     | 3     | 5         |
