Feature: Doc strings

  Scenario: API response
    Given the API returns:
      """
      {
        "status": "ok",
        "count": 42
      }
      """
    When I parse the response
    Then the status should be "ok"

  Scenario: Multi-line text
    Given I have a document with content:
      """
      First line
      Second line
      Third line
      """
    Then the document should have 3 lines
