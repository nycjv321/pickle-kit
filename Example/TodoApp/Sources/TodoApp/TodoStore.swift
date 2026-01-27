import Foundation
import Observation

@Observable
final class TodoStore {
    private(set) var todos: [TodoItem] = []

    func add(title: String) {
        todos.append(TodoItem(title: title))
    }

    func add(titles: [String]) {
        todos.append(contentsOf: titles.map { TodoItem(title: $0) })
    }

    func remove(at index: Int) {
        guard todos.indices.contains(index) else { return }
        todos.remove(at: index)
    }

    func updateTitle(at index: Int, title: String) {
        guard todos.indices.contains(index) else { return }
        todos[index].title = title
    }

    func setCompleted(at index: Int, _ isCompleted: Bool) {
        guard todos.indices.contains(index) else { return }
        todos[index].isCompleted = isCompleted
    }

    func clear() {
        todos.removeAll()
    }
}
