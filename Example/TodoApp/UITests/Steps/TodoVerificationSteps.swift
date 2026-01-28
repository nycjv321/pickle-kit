import XCTest
import PickleKit

struct TodoVerificationSteps: StepDefinitions {
    let emptyStateVisible: StepDefinition = .then("I should see the empty state message") { _ in
        XCTAssertTrue(TodoWindow.emptyStateText.waitForExistence(timeout: 5), "Expected empty state message to be visible")
    }

    let seeTextAtPosition: StepDefinition = .then("I should see \"([^\"]*)\" at position (\\d+)") { match in
        let expectedText = match.captures[0]
        let index = Int(match.captures[1])!
        let label = TodoWindow.todoText(at: index)
        XCTAssertTrue(label.waitForExistence(timeout: 5), "Expected todo text at position \(index) to exist")
        XCTAssertEqual(label.value as? String, expectedText, "Unexpected text at position \(index)")
    }

    let itemCount: StepDefinition = .then("the item count should be (\\d+)") { match in
        let expected = Int(match.captures[0])!
        let countLabel = TodoWindow.todoCount
        XCTAssertTrue(countLabel.waitForExistence(timeout: 5), "Count label did not appear")
        let suffix = expected == 1 ? "item" : "items"
        let expectedText = "\(expected) \(suffix)"
        XCTAssertEqual(countLabel.value as? String, expectedText, "Unexpected count label text")
    }

    let countLabelReads: StepDefinition = .then("the count label should read \"([^\"]*)\"") { match in
        let expectedText = match.captures[0]
        let countLabel = TodoWindow.todoCount
        XCTAssertTrue(countLabel.waitForExistence(timeout: 5), "Count label did not appear")
        XCTAssertEqual(countLabel.value as? String, expectedText, "Unexpected count label text")
    }

    let addButtonDisabled: StepDefinition = .then("the add button should be disabled") { _ in
        let button = TodoWindow.addButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Add button did not appear")
        XCTAssertFalse(button.isEnabled, "Expected add button to be disabled")
    }

    let todoCompleted: StepDefinition = .then("the todo at position (\\d+) should be completed") { match in
        let index = Int(match.captures[0])!
        let toggle = TodoWindow.todoToggle(at: index)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Toggle at position \(index) did not appear")
        XCTAssertEqual(toggle.value as? Int, 1, "Expected todo at position \(index) to be completed")
    }

    let todoNotCompleted: StepDefinition = .then("the todo at position (\\d+) should not be completed") { match in
        let index = Int(match.captures[0])!
        let toggle = TodoWindow.todoToggle(at: index)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Toggle at position \(index) did not appear")
        XCTAssertEqual(toggle.value as? Int, 0, "Expected todo at position \(index) to not be completed")
    }
}
