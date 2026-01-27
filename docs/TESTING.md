# Test Design Philosophy

This document covers the reasoning behind PickleKit's testing approach, the recommended test pyramid for projects using PickleKit, and practical rules for writing UI tests.

## Why BDD / Why PickleKit

### Unit Tests vs. BDD Tests

Unit tests verify that individual functions and types behave correctly in isolation. They answer "does this code work?" BDD tests verify behavior from the user's perspective using natural-language scenarios. They answer "does this feature work the way a user expects?"

Gherkin feature files serve as living documentation that non-engineers can read, review, and contribute to. A product manager can read:

```gherkin
Scenario: Add a single todo
  When I enter "Buy groceries" in the text field
  And I tap the add button
  Then I should see "Buy groceries" at position 0
```

and understand exactly what the test covers without reading Swift code.

### Why PickleKit Exists

Before PickleKit, using Cucumber-style BDD in Swift required external toolchains — Ruby (via Cucumber), Java (via Karate), or CocoaPods-based frameworks. PickleKit provides a zero-dependency Swift-native Cucumber framework that integrates directly with XCTest. No Gemfile, no Podfile, no build plugins — just a Swift package dependency.

### When to Use Each

| Test Type | Use For | Example |
|-----------|---------|---------|
| Unit tests | Domain logic, model behavior, pure functions | `TodoStore.add(title:)` adds an item, `TodoStore.clear()` removes all items |
| BDD / Gherkin | End-to-end user flows, acceptance criteria | "Add a todo and verify it appears in the list" |

Use unit tests for anything that can be tested without UI. Use Gherkin scenarios for flows that exercise the full stack from user interaction through to visible result.

## Test Pyramid for PickleKit Projects

```
        /  UI / Acceptance  \        ← Fewest: critical user flows (GherkinTestCase + XCUITest)
       /  Integration Tests  \       ← Middle: parser + runner pipeline (GherkinIntegrationTests)
      /     Unit Tests        \      ← Most: model, store, logic (TodoStoreTests, ParserTests, etc.)
```

### Unit Tests

Fast, isolated tests covering model and store logic. These form the base of the pyramid and should be the majority of your test suite.

- **Framework tests**: `ParserTests`, `StepRegistryTests`, `ScenarioRunnerTests`, `TagFilterTests`, `StepResultTests`, `HTMLReportGeneratorTests`
- **App tests**: `TodoStoreTests` — verifies add, remove, update, clear, toggle completion without any UI

### Integration Tests

End-to-end tests of the PickleKit pipeline: parse Gherkin → expand outlines → register steps → run scenarios → collect results.

- `GherkinIntegrationTests` — a `GherkinTestCase` subclass that runs all fixture `.feature` files through the full pipeline

### UI / Acceptance Tests

Gherkin scenarios driving XCUITest. These are the slowest and most expensive tests. Use them for critical user flows, not exhaustive edge cases.

- `TodoUITests` — drives the TodoApp through XCUIApplication, verifying add, delete, edit, toggle, batch operations, and empty state

Unit tests should be the majority. UI tests should cover the critical paths that users actually traverse.

## UI Test Design Rules

These rules apply when writing `GherkinTestCase` subclasses that drive XCUITest.

### Launch the App Once

`setUp()` calls `launch()` only on the first scenario, then `activate()` for subsequent ones. This avoids the overhead of a full app launch per scenario.

```swift
override func setUp() {
    super.setUp()
    if Self.app == nil {
        Self.app = XCUIApplication()
        Self.app.launchArguments.append("-disableAnimations")
        Self.app.launch()
    } else {
        Self.app.activate()
    }
}
```

### Reset State via Background Steps, Not Relaunch

Each scenario's `Background` clicks "Clear All" to return to a known state without relaunching the app. This is faster and more reliable than tearing down and relaunching.

```gherkin
Background:
  Given the app is launched
  And the todo list is empty
```

### Bypass the UI for Setup When Possible

Use URL schemes or other programmatic mechanisms to seed data rather than clicking through the UI step-by-step. The TodoApp uses `todoapp://seed?todos=["item1","item2"]` to populate todos in a single call — faster and less flaky than entering each item through the text field.

```swift
given("the following todos exist:") { match in
    let titles = match.dataTable!.dataRows.map { $0[0] }
    let json = try JSONEncoder().encode(titles)
    let encoded = String(data: json, encoding: .utf8)!
    let url = URL(string: "todoapp://seed?todos=\(encoded)")!
    Self.app.open(url)
}
```

### Use `waitForExistence(timeout:)` on Every Element Query

UI updates and assertions race against each other. Always use `waitForExistence(timeout:)` to prevent flakiness:

```swift
let element = app.staticTexts["todoText_0"]
XCTAssertTrue(element.waitForExistence(timeout: 5))
```

### Deterministic Accessibility Identifiers

Use index-based IDs (`todoText_0`, `editButton_1`) from `ForEach(Array(todos.enumerated()))`. Avoid relying on element text for queries — text can change, but identifiers are stable.

### Single-Window Scene

Use `Window` instead of `WindowGroup` for apps under UI test. `WindowGroup` can create duplicate windows when handling URLs, which confuses XCUITest element queries.

### `nonisolated(unsafe) static var app`

`XCUIApplication` isn't `Sendable`, but `StepHandler` requires `@Sendable` closures. Storing the app as a `nonisolated(unsafe) static var` is safe because XCUITest runs scenarios sequentially — there is no concurrent access.
