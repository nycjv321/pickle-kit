# Test Design Philosophy

This document covers the reasoning behind PickleKit's testing approach, the recommended testing strategy for projects using PickleKit, and practical rules for writing UI tests.

## Why BDD

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

### When to Use Each

| Test Type | Use For | Example |
|-----------|---------|---------|
| Unit tests | Domain logic, model behavior, pure functions | `TodoStore.add(title:)` adds an item, `TodoStore.clear()` removes all items |
| BDD / Gherkin | End-to-end user flows, acceptance criteria | "Add a todo and verify it appears in the list" |

Use unit tests for anything that can be tested without UI. Use Gherkin scenarios for flows that exercise the full stack from user interaction through to visible result.

## Testing Trophy for PickleKit Projects

The **Testing Trophy** (Kent C. Dodds) and **Testing Honeycomb** (Spotify) are modern alternatives to the traditional test pyramid. Their core insight: most applications are integrations — unit tests in isolation cannot validate that components work together correctly.

> "The more your tests resemble the way your software is used, the more confidence they can give you." — Kent C. Dodds

The trophy has four layers, with integration tests forming the widest band:

```
          ╭──╮
          │E2E│                ← Selective: critical user flows (GherkinTestCase + XCUITest)
       ╭──┴──┴──╮
       │         │
    ╭──┤Integr-  ├──╮
    │  │  ation  │  │         ← Most investment: full pipeline (GherkinIntegrationTests)
    │  │         │  │
    ╰──┴─────────┴──╯
       ╭─────────╮
       │  Unit   │            ← Targeted: pure logic (TodoStore, parser internals)
       ╰─────────╯
       ╭─────────╮
       │ Static  │            ← Swift compiler, type system, linter
       ╰─────────╯
```

PickleKit covers the **E2E / acceptance** layer of the trophy — human-readable Cucumber scenarios that verify real user flows through the full stack.

### Unit Tests

Valuable for pure logic and isolated components, but not the primary confidence driver. Use them where the input/output boundary is clear and no integration wiring is needed.

- **Framework tests**: `ParserTests`, `StepRegistryTests`, `ScenarioRunnerTests`, `TagFilterTests`, `StepResultTests`, `HTMLReportGeneratorTests`
- **App tests**: `TodoStoreTests` — verifies add, remove, update, clear, toggle completion without any UI

### Integration Tests

The sweet spot for confidence. These exercise real components working together and catch the class of bugs that unit tests miss: wiring errors, contract mismatches, and incorrect assumptions between layers.

- `GherkinIntegrationTests` — a `GherkinTestCase` subclass that runs all fixture `.feature` files through the full parse → expand → register → run pipeline
- Most testing effort should go here. When in doubt about where to add a test, prefer an integration test over a unit test

### UI / Acceptance Tests (E2E)

PickleKit + XCUITest covers this layer. These tests verify critical user flows in human-readable Gherkin and are the only tests that exercise the real UI rendering and interaction layer. Use them selectively for flows that can only be validated through the real UI.

- `TodoUITests` — drives the TodoApp through XCUIApplication, verifying add, delete, edit, toggle, batch operations, and empty state
- Keep E2E tests focused on critical paths. Edge cases and error conditions are better covered at the integration or unit layer

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

### Grey-Box Testing: Bypass the UI for Setup

In web and API applications, grey-box testing means calling the API directly from test code to set up state — for example, `POST /api/todos` to seed data — rather than clicking through the UI. The test is "grey-box" because it uses internal knowledge of the app's interfaces while still asserting against the external UI.

iOS and macOS apps don't expose REST APIs, but they do have URL schemes and deep links. `todoapp://seed?todos=[...]` serves the same purpose as a `POST /api/seed` endpoint — it lets tests set up preconditions programmatically without touching the UI.

Why this matters:

- **Faster**: Skips UI animations and input latency. Seeding via URL is near-instant compared to typing into text fields and tapping buttons
- **More deterministic**: No risk of flaky text entry, missed taps, or timing issues during setup steps
- **More reliable**: Fewer moving parts in the setup path means fewer false failures
- **Focused assertions**: Tests assert only the behavior under test, not the correctness of the setup path

The TodoApp uses `todoapp://seed?todos=["item1","item2"]` to populate todos in a single call:

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

## Continuous Integration

PickleKit uses GitHub Actions to run the full test suite on every push and pull request. The pipeline has three jobs:

```
unit-tests ──┬──> ui-tests
             └──> build
```

### How Tests Run in CI

- **PickleKit library tests** run via `swift test` with code coverage enabled
- **TodoApp unit tests** run via `xcodebuild -only-testing:TodoAppTests`
- **TodoApp UI tests** run via `xcodebuild -only-testing:TodoAppUITests` in a separate job that depends on unit tests passing first
- **Release build** validation runs `swift build -c release` in parallel with UI tests

### CI Requirements for UI Tests

UI tests require a GUI session on the CI runner. The pipeline enables `DevToolsSecurity` and waits for accessibility permissions before running UI tests. CI runners use `macos-14` with the latest stable Xcode.

### Test Reporting

CI generates JUnit XML reports via `xcbeautify --report junit --report-path .` and publishes them with `dorny/test-reporter`. This surfaces test results directly in the GitHub Actions UI.

See [Release Process](RELEASE.md) for the full CI pipeline diagram, job details, and the automated release workflow.
