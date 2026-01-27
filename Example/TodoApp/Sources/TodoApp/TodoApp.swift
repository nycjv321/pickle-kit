import SwiftUI

@main
struct TodoApp: App {
    private let disableAnimations = CommandLine.arguments.contains("-disableAnimations")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .transaction { transaction in
                    if disableAnimations {
                        transaction.disablesAnimations = true
                    }
                }
        }
    }
}
