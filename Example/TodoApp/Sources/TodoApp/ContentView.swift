import SwiftUI

struct ContentView: View {
    @State private var todos: [TodoItem] = []
    @State private var newTodoText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Add a new todo...", text: $newTodoText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("todoTextField")
                    .onSubmit(addTodo)

                Button("Add") {
                    addTodo()
                }
                .accessibilityIdentifier("addButton")
                .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if todos.isEmpty {
                Spacer()
                Text("No todos yet. Add one above!")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyStateText")
                Spacer()
            } else {
                List {
                    ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { todos[index].isCompleted },
                                set: { todos[index].isCompleted = $0 }
                            )) {
                                EmptyView()
                            }
                            .toggleStyle(.checkbox)
                            .accessibilityIdentifier("todoToggle_\(index)")

                            Text(todo.title)
                                .strikethrough(todo.isCompleted)
                                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                .accessibilityIdentifier("todoText_\(index)")

                            Spacer()

                            Button(role: .destructive) {
                                deleteTodo(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("deleteButton_\(index)")
                        }
                    }
                }
            }

            HStack {
                Text("\(todos.count) item\(todos.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .accessibilityIdentifier("todoCount")
                Spacer()
                if !todos.isEmpty {
                    Button("Clear All") { todos.removeAll() }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("clearAllButton")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func addTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(title: trimmed))
        newTodoText = ""
    }

    private func deleteTodo(at index: Int) {
        todos.remove(at: index)
    }
}
