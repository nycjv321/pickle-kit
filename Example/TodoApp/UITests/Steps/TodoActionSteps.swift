import XCTest
import PickleKit

struct TodoActionSteps: StepDefinitions {
    let enterText: StepDefinition = .when("I enter \"([^\"]*)\" in the text field") { match in
        let text = match.captures[0]
        TodoWindow.enterText(text)
    }

    let tapAdd: StepDefinition = .when("I tap the add button") { _ in
        TodoWindow.tapAdd()
    }

    let updateTodo: StepDefinition = .when("I update the todo at position (\\d+) to \"([^\"]*)\"") { match in
        let index = Int(match.captures[0])!
        let newText = match.captures[1]
        TodoWindow.editTodo(at: index, to: newText)
    }

    let deleteTodo: StepDefinition = .when("I delete the todo at position (\\d+)") { match in
        let index = Int(match.captures[0])!
        TodoWindow.deleteTodo(at: index)
    }

    let toggleTodo: StepDefinition = .when("I toggle the todo at position (\\d+)") { match in
        let index = Int(match.captures[0])!
        TodoWindow.toggleTodo(at: index)
    }

    let addFromTable: StepDefinition = .when("I add the following todos:") { match in
        let rows = match.dataTable!.dataRows
        for row in rows {
            TodoWindow.addTodo(row[0])
        }
    }

    let addNumbered: StepDefinition = .when("I add (\\d+) todos with prefix \"([^\"]*)\"") { match in
        let count = Int(match.captures[0])!
        let prefix = match.captures[1]
        for i in 1...count {
            TodoWindow.addTodo("\(prefix) \(i)")
        }
    }
}
