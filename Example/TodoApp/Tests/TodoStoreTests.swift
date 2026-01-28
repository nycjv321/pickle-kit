import Testing
@testable import TodoApp

@Suite struct TodoStoreTests {

    @Test func initialStateIsEmpty() {
        let store = TodoStore()
        #expect(store.todos.isEmpty)
    }

    // MARK: - add(title:)

    @Test func addSingleTodo() {
        let store = TodoStore()
        store.add(title: "Buy milk")
        #expect(store.todos.count == 1)
        #expect(store.todos[0].title == "Buy milk")
        #expect(!store.todos[0].isCompleted)
    }

    @Test func addMultipleSingleTodos() {
        let store = TodoStore()
        store.add(title: "First")
        store.add(title: "Second")
        #expect(store.todos.count == 2)
        #expect(store.todos[0].title == "First")
        #expect(store.todos[1].title == "Second")
    }

    // MARK: - add(titles:)

    @Test func addTitlesAppendsToExisting() {
        let store = TodoStore()
        store.add(title: "Old item")
        store.add(titles: ["New A", "New B"])
        #expect(store.todos.count == 3)
        #expect(store.todos[0].title == "Old item")
        #expect(store.todos[1].title == "New A")
        #expect(store.todos[2].title == "New B")
    }

    @Test func addTitlesOnEmptyStore() {
        let store = TodoStore()
        store.add(titles: ["A", "B"])
        #expect(store.todos.count == 2)
        #expect(store.todos[0].title == "A")
        #expect(store.todos[1].title == "B")
    }

    @Test func addEmptyTitles() {
        let store = TodoStore()
        store.add(title: "Existing")
        store.add(titles: [])
        #expect(store.todos.count == 1)
        #expect(store.todos[0].title == "Existing")
    }

    // MARK: - clear()

    @Test func clearRemovesAllTodos() {
        let store = TodoStore()
        store.add(title: "A")
        store.add(title: "B")
        store.clear()
        #expect(store.todos.isEmpty)
    }

    @Test func clearOnEmptyStore() {
        let store = TodoStore()
        store.clear()
        #expect(store.todos.isEmpty)
    }

    // MARK: - remove(at:)

    @Test func removeAtValidIndex() {
        let store = TodoStore()
        store.add(titles: ["A", "B", "C"])
        store.remove(at: 1)
        #expect(store.todos.count == 2)
        #expect(store.todos[0].title == "A")
        #expect(store.todos[1].title == "C")
    }

    @Test func removeAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.remove(at: 5)
        #expect(store.todos.count == 1)
    }

    @Test func removeAtNegativeIndex() {
        let store = TodoStore()
        store.add(title: "Only")
        store.remove(at: -1)
        #expect(store.todos.count == 1)
    }

    // MARK: - updateTitle(at:title:)

    @Test func updateTitleAtValidIndex() {
        let store = TodoStore()
        store.add(titles: ["Old title", "Other"])
        store.updateTitle(at: 0, title: "New title")
        #expect(store.todos[0].title == "New title")
        #expect(store.todos[1].title == "Other")
    }

    @Test func updateTitleAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.updateTitle(at: 10, title: "Should not crash")
        #expect(store.todos[0].title == "Only")
    }

    // MARK: - setCompleted(at:_:)

    @Test func setCompletedAtValidIndex() {
        let store = TodoStore()
        store.add(title: "Task")
        #expect(!store.todos[0].isCompleted)
        store.setCompleted(at: 0, true)
        #expect(store.todos[0].isCompleted)
        store.setCompleted(at: 0, false)
        #expect(!store.todos[0].isCompleted)
    }

    @Test func setCompletedAtOutOfBounds() {
        let store = TodoStore()
        store.add(title: "Only")
        store.setCompleted(at: 5, true)
        #expect(!store.todos[0].isCompleted)
    }
}
