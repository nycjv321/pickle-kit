import XCTest
@testable import TodoApp

final class TodoStoreTests: XCTestCase {

    func testInitialStateIsEmpty() {
        let store = TodoStore()
        XCTAssertTrue(store.todos.isEmpty)
    }

    // MARK: - add(title:)

    func testAddSingleTodo() {
        let store = TodoStore()
        store.add(title: "Buy milk")
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos[0].title, "Buy milk")
        XCTAssertFalse(store.todos[0].isCompleted)
    }

    func testAddMultipleSingleTodos() {
        let store = TodoStore()
        store.add(title: "First")
        store.add(title: "Second")
        XCTAssertEqual(store.todos.count, 2)
        XCTAssertEqual(store.todos[0].title, "First")
        XCTAssertEqual(store.todos[1].title, "Second")
    }

    // MARK: - add(titles:)

    func testAddTitlesAppendsToExisting() {
        let store = TodoStore()
        store.add(title: "Old item")
        store.add(titles: ["New A", "New B"])
        XCTAssertEqual(store.todos.count, 3)
        XCTAssertEqual(store.todos[0].title, "Old item")
        XCTAssertEqual(store.todos[1].title, "New A")
        XCTAssertEqual(store.todos[2].title, "New B")
    }

    func testAddTitlesOnEmptyStore() {
        let store = TodoStore()
        store.add(titles: ["A", "B"])
        XCTAssertEqual(store.todos.count, 2)
        XCTAssertEqual(store.todos[0].title, "A")
        XCTAssertEqual(store.todos[1].title, "B")
    }

    func testAddEmptyTitles() {
        let store = TodoStore()
        store.add(title: "Existing")
        store.add(titles: [])
        XCTAssertEqual(store.todos.count, 1)
        XCTAssertEqual(store.todos[0].title, "Existing")
    }

    // MARK: - clear()

    func testClearRemovesAllTodos() {
        let store = TodoStore()
        store.add(title: "A")
        store.add(title: "B")
        store.clear()
        XCTAssertTrue(store.todos.isEmpty)
    }

    func testClearOnEmptyStore() {
        let store = TodoStore()
        store.clear()
        XCTAssertTrue(store.todos.isEmpty)
    }

    // MARK: - remove(at:)

    func testRemoveAtValidIndex() {
        let store = TodoStore()
        store.add(titles: ["A", "B", "C"])
        store.remove(at: 1)
        XCTAssertEqual(store.todos.count, 2)
        XCTAssertEqual(store.todos[0].title, "A")
        XCTAssertEqual(store.todos[1].title, "C")
    }

    func testRemoveAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.remove(at: 5)
        XCTAssertEqual(store.todos.count, 1)
    }

    func testRemoveAtNegativeIndex() {
        let store = TodoStore()
        store.add(title: "Only")
        store.remove(at: -1)
        XCTAssertEqual(store.todos.count, 1)
    }

    // MARK: - updateTitle(at:title:)

    func testUpdateTitleAtValidIndex() {
        let store = TodoStore()
        store.add(titles: ["Old title", "Other"])
        store.updateTitle(at: 0, title: "New title")
        XCTAssertEqual(store.todos[0].title, "New title")
        XCTAssertEqual(store.todos[1].title, "Other")
    }

    func testUpdateTitleAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.updateTitle(at: 10, title: "Should not crash")
        XCTAssertEqual(store.todos[0].title, "Only")
    }

    // MARK: - setCompleted(at:_:)

    func testSetCompletedAtValidIndex() {
        let store = TodoStore()
        store.add(title: "Task")
        XCTAssertFalse(store.todos[0].isCompleted)
        store.setCompleted(at: 0, true)
        XCTAssertTrue(store.todos[0].isCompleted)
        store.setCompleted(at: 0, false)
        XCTAssertFalse(store.todos[0].isCompleted)
    }

    func testSetCompletedAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.setCompleted(at: 5, true)
        XCTAssertFalse(store.todos[0].isCompleted)
    }
}
