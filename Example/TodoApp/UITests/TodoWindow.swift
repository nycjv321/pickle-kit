import XCTest

struct TodoWindow {
    // XCUIApplication is not Sendable, but XCUITest runs scenarios sequentially,
    // so this is safe in practice.
    nonisolated(unsafe) static var app: XCUIApplication!

    // MARK: - Element Accessors

    static var todoTextField: XCUIElement { app.textFields["todoTextField"] }
    static var addButton: XCUIElement { app.buttons["addButton"] }
    static var emptyStateText: XCUIElement { app.staticTexts["emptyStateText"] }
    static var todoCount: XCUIElement { app.staticTexts["todoCount"] }
    static var clearAllButton: XCUIElement { app.buttons["clearAllButton"] }

    static func todoText(at index: Int) -> XCUIElement {
        app.staticTexts["todoText_\(index)"]
    }

    static func editButton(at index: Int) -> XCUIElement {
        app.buttons["editButton_\(index)"]
    }

    static func deleteButton(at index: Int) -> XCUIElement {
        app.buttons["deleteButton_\(index)"]
    }

    static func todoToggle(at index: Int) -> XCUIElement {
        app.checkBoxes["todoToggle_\(index)"]
    }

    static func editTextField(at index: Int) -> XCUIElement {
        app.textFields["editTextField_\(index)"]
    }

    // MARK: - Actions

    /// Paste text into an element via NSPasteboard (much faster than typeText).
    /// Step handlers run on @MainActor, so no dispatch is needed.
    static func pasteText(_ text: String, into element: XCUIElement) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        element.typeKey("a", modifierFlags: .command)
        element.typeKey("v", modifierFlags: .command)
    }

    /// Click the Clear All button if it exists, removing all todos.
    static func clearAll() {
        if clearAllButton.waitForExistence(timeout: 0.5) {
            clearAllButton.click()
        }
    }

    /// Click the text field and paste text into it.
    static func enterText(_ text: String) {
        XCTAssertTrue(todoTextField.waitForExistence(timeout: 5))
        todoTextField.click()
        pasteText(text, into: todoTextField)
    }

    /// Click the add button.
    static func tapAdd() {
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()
    }

    /// Enter text and tap add to create a todo.
    static func addTodo(_ title: String) {
        enterText(title)
        tapAdd()
    }

    /// Delete the todo at the given index.
    static func deleteTodo(at index: Int) {
        let button = deleteButton(at: index)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.click()
    }

    /// Toggle the completion state of the todo at the given index.
    static func toggleTodo(at index: Int) {
        let toggle = todoToggle(at: index)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.click()
    }

    /// Click edit, paste new text, and confirm with Return.
    static func editTodo(at index: Int, to newText: String) {
        let edit = editButton(at: index)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.click()

        let field = editTextField(at: index)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        pasteText(newText, into: field)
        field.typeKey(.return, modifierFlags: [])
    }

    /// Seed the todo list via the URL scheme for fast, deterministic setup.
    static func seedTodos(_ titles: [String]) {
        let jsonData = try! JSONEncoder().encode(titles)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        let encoded = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "todoapp://seed?todos=\(encoded)")!
        NSWorkspace.shared.open(url)
    }
}
