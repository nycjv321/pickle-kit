import XCTest
import PickleKit

final class TodoUITests: GherkinTestCase {

    override class var featureSubdirectory: String? { "Features" }

    override class var tagFilter: TagFilter? {
        TagFilter(excludeTags: ["wip"])
    }

    // XCUIApplication is not Sendable, but XCUITest runs scenarios sequentially,
    // so this is safe in practice.
    nonisolated(unsafe) static var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        Self.app = XCUIApplication()
        Self.app.launch()
    }

    override func tearDown() {
        Self.app?.terminate()
        Self.app = nil
        super.tearDown()
    }

    override func registerStepDefinitions() {
        // MARK: - Given

        given("the app is launched") { _ in
            let app = TodoUITests.app!
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        }

        given("the todo list is empty") { _ in
            let app = TodoUITests.app!
            let emptyState = app.staticTexts["emptyStateText"]
            // The list should be empty on fresh launch
            XCTAssertTrue(
                emptyState.waitForExistence(timeout: 5),
                "Expected empty state on fresh launch"
            )
        }

        // MARK: - When

        when("I enter \"([^\"]*)\" in the text field") { match in
            let app = TodoUITests.app!
            let text = match.captures[0]
            let textField = app.textFields["todoTextField"]
            XCTAssertTrue(textField.waitForExistence(timeout: 5))
            textField.click()
            // Select all existing text and replace
            textField.typeKey("a", modifierFlags: .command)
            textField.typeText(text)
        }

        when("I tap the add button") { _ in
            let app = TodoUITests.app!
            let addButton = app.buttons["addButton"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 5))
            addButton.click()
        }

        when("I delete the todo at position (\\d+)") { match in
            let app = TodoUITests.app!
            let index = Int(match.captures[0])!
            let deleteButton = app.buttons["deleteButton_\(index)"]
            XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
            deleteButton.click()
        }

        when("I toggle the todo at position (\\d+)") { match in
            let app = TodoUITests.app!
            let index = Int(match.captures[0])!
            let toggle = app.checkBoxes["todoToggle_\(index)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.click()
        }

        when("I add the following todos:") { match in
            let app = TodoUITests.app!
            let rows = match.dataTable!.dataRows
            for row in rows {
                let title = row[0]
                let textField = app.textFields["todoTextField"]
                XCTAssertTrue(textField.waitForExistence(timeout: 5))
                textField.click()
                textField.typeKey("a", modifierFlags: .command)
                textField.typeText(title)

                let addButton = app.buttons["addButton"]
                XCTAssertTrue(addButton.waitForExistence(timeout: 5))
                addButton.click()
            }
        }

        when("I add (\\d+) todos with prefix \"([^\"]*)\"") { match in
            let app = TodoUITests.app!
            let count = Int(match.captures[0])!
            let prefix = match.captures[1]
            for i in 1...count {
                let textField = app.textFields["todoTextField"]
                XCTAssertTrue(textField.waitForExistence(timeout: 5))
                textField.click()
                textField.typeKey("a", modifierFlags: .command)
                textField.typeText("\(prefix) \(i)")

                let addButton = app.buttons["addButton"]
                XCTAssertTrue(addButton.waitForExistence(timeout: 5))
                addButton.click()
            }
        }

        // MARK: - Then

        then("I should see the empty state message") { _ in
            let app = TodoUITests.app!
            let emptyState = app.staticTexts["emptyStateText"]
            XCTAssertTrue(
                emptyState.waitForExistence(timeout: 5),
                "Expected empty state message to be visible"
            )
        }

        then("I should see \"([^\"]*)\" at position (\\d+)") { match in
            let app = TodoUITests.app!
            let expectedText = match.captures[0]
            let index = Int(match.captures[1])!
            let label = app.staticTexts["todoText_\(index)"]
            XCTAssertTrue(
                label.waitForExistence(timeout: 5),
                "Expected todo text at position \(index) to exist"
            )
            XCTAssertEqual(label.value as? String, expectedText)
        }

        then("the item count should be (\\d+)") { match in
            let app = TodoUITests.app!
            let expected = Int(match.captures[0])!
            let countLabel = app.staticTexts["todoCount"]
            XCTAssertTrue(countLabel.waitForExistence(timeout: 5))
            let suffix = expected == 1 ? "item" : "items"
            XCTAssertEqual(countLabel.value as? String, "\(expected) \(suffix)")
        }

        then("the count label should read \"([^\"]*)\"") { match in
            let app = TodoUITests.app!
            let expectedText = match.captures[0]
            let countLabel = app.staticTexts["todoCount"]
            XCTAssertTrue(countLabel.waitForExistence(timeout: 5))
            XCTAssertEqual(countLabel.value as? String, expectedText)
        }

        then("the add button should be disabled") { _ in
            let app = TodoUITests.app!
            let addButton = app.buttons["addButton"]
            XCTAssertTrue(addButton.waitForExistence(timeout: 5))
            XCTAssertFalse(addButton.isEnabled, "Expected add button to be disabled")
        }

        then("the todo at position (\\d+) should be completed") { match in
            let app = TodoUITests.app!
            let index = Int(match.captures[0])!
            let toggle = app.checkBoxes["todoToggle_\(index)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            XCTAssertEqual(toggle.value as? Int, 1, "Expected todo at position \(index) to be completed")
        }

        then("the todo at position (\\d+) should not be completed") { match in
            let app = TodoUITests.app!
            let index = Int(match.captures[0])!
            let toggle = app.checkBoxes["todoToggle_\(index)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            XCTAssertEqual(toggle.value as? Int, 0, "Expected todo at position \(index) to not be completed")
        }
    }
}
