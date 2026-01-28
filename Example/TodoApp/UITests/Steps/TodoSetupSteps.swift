import XCTest
import PickleKit

struct TodoSetupSteps: StepDefinitions {
    let appLaunched: StepDefinition = .given("the app is launched") { _ in
        XCTAssertTrue(TodoWindow.app.wait(for: .runningForeground, timeout: 5), "App did not reach foreground")
    }

    let emptyList: StepDefinition = .given("the todo list is empty") { _ in
        TodoWindow.clearAll()
        XCTAssertTrue(TodoWindow.emptyStateText.waitForExistence(timeout: 5), "Expected empty state after clearing")
    }

    let seedTodos: StepDefinition = .given("I have the following todos in my list:") { match in
        let titles = match.dataTable!.dataRows.map { $0[0] }
        TodoWindow.seedTodos(titles)
        XCTAssertTrue(TodoWindow.todoText(at: 0).waitForExistence(timeout: 5), "Expected seeded todos to appear")
    }
}
