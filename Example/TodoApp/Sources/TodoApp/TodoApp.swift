import SwiftUI

@main
struct TodoApp: App {
    private let disableAnimations = CommandLine.arguments.contains("-disableAnimations")
    @State private var store = TodoStore()

    var body: some Scene {
        Window("TodoApp", id: "main") {
            ContentView(store: store)
                .transaction { transaction in
                    if disableAnimations {
                        transaction.disablesAnimations = true
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == "todoapp" else { return }
                    switch url.host {
                    case "seed":
                        if let query = URLComponents(url: url, resolvingAgainstBaseURL: false),
                           let param = query.queryItems?.first(where: { $0.name == "todos" })?.value,
                           let data = param.data(using: .utf8),
                           let titles = try? JSONDecoder().decode([String].self, from: data) {
                            store.clear()
                            store.add(titles: titles)
                        }
                    default:
                        break
                    }
                }
        }
    }
}
