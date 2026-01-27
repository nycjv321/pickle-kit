import XCTest
import PickleKit

final class TodoUITests: GherkinTestCase {

    override class var featureSubdirectory: String? { "Features" }

    override class var tagFilter: TagFilter? {
        TagFilter(excludeTags: ["wip"])
    }

    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [TodoSetupSteps.self, TodoActionSteps.self, TodoVerificationSteps.self]
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        if TodoWindow.app == nil {
            TodoWindow.app = XCUIApplication()
            TodoWindow.app.launchArguments.append("-disableAnimations")
            TodoWindow.app.launch()
            XCTAssertTrue(
                TodoWindow.app.windows.firstMatch.waitForExistence(timeout: 10),
                "App window accessibility tree did not load"
            )
        } else {
            TodoWindow.app.activate()
        }
    }
}
