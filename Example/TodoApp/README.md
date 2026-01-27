# TodoApp Example

A minimal macOS SwiftUI todo app demonstrating PickleKit with XCUITest.

## Prerequisites

- macOS 14+
- Xcode 15+ (with command line tools selected — `xcode-select -p` should show `/Applications/Xcode.app/...`)
- [xcodegen](https://github.com/yonaskolb/XcodeGen)
- [xcbeautify](https://github.com/cpisciotta/xcbeautify)

Install dependencies if you don't have them:

```bash
brew install xcodegen xcbeautify
```

## Quick Start

```bash
# From the repository root
cd Example/TodoApp
xcodegen generate
xcodebuild test -project TodoApp.xcodeproj -scheme TodoApp -destination 'platform=macOS' 2>&1 | xcbeautify
```

## Setup

The Xcode project is generated from `project.yml` using xcodegen. The `.xcodeproj` is gitignored — you regenerate it locally.

```bash
cd Example/TodoApp
xcodegen generate
```

This creates `TodoApp.xcodeproj` with three targets:
- **TodoApp** — the macOS SwiftUI application
- **TodoAppTests** — unit tests for `TodoStore` (no UI dependency)
- **TodoAppUITests** — the XCUITest bundle with PickleKit

If you change `project.yml`, re-run `xcodegen generate` to regenerate the project.

## Launching the App

> **Note:** You must run `xcodegen generate` first (see [Setup](#setup)) — the `.xcodeproj` is not checked into the repo.

### From Xcode

1. Open `TodoApp.xcodeproj`
2. Select the **TodoApp** scheme in the toolbar
3. Press **Cmd+R** to build and run

The app window shows a text field, an Add button, and a list area. Type a todo and click Add (or press Return) to add items. Each item has a checkbox to toggle completion and a trash icon to delete.

### From the command line

```bash
# Build and run (launches the app)
cd Example/TodoApp
xcodebuild build -project TodoApp.xcodeproj -scheme TodoApp -destination 'platform=macOS' 2>&1 | xcbeautify
open ~/Library/Developer/Xcode/DerivedData/TodoApp-*/Build/Products/Debug/TodoApp.app
```

## Running Tests

### Run all tests from the command line

```bash
cd Example/TodoApp
xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' 2>&1 | xcbeautify
```

This runs both unit tests (`TodoAppTests`) and UI tests (`TodoAppUITests`). The UI tests launch the TodoApp, run all non-`@wip` scenarios (~11 scenarios), and report results. You'll see the app window briefly appear and interact during each scenario.

For a detailed breakdown with step-level results and timing, see [HTML Test Reports](#html-test-reports).

### Run unit tests only

```bash
cd Example/TodoApp
xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' \
  -only-testing:TodoAppTests 2>&1 | xcbeautify
```

Unit tests verify `TodoStore` logic (add, remove, update, clear, toggle) without launching the app.

### Run UI tests only

```bash
cd Example/TodoApp
xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' \
  -only-testing:TodoAppUITests 2>&1 | xcbeautify
```

### Run all tests from Xcode

1. Open `TodoApp.xcodeproj`
2. Select the **TodoApp** scheme in the toolbar
3. Press **Cmd+U** to run all tests

You'll see the app window briefly appear and interact during each scenario. Results appear in the test navigator.

### Run a specific scenario

Use `xcodebuild`'s `-only-testing` flag with the test class and method name. Scenario names are sanitized into method names (spaces become underscores, special characters removed, prefixed with `test_`):

```bash
# Run just the "Add a single todo" scenario
xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' \
  -only-testing 'TodoAppUITests/TodoUITests/test_Add_a_single_todo' 2>&1 | xcbeautify
```

In Xcode, click the diamond icon next to any individual test in the test navigator to run just that one.

### Run scenarios by tag

Use the `CUCUMBER_TAGS` environment variable to include only scenarios matching specific tags:

```bash
# Run only @smoke scenarios
CUCUMBER_TAGS=smoke xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' 2>&1 | xcbeautify
```

Use `CUCUMBER_EXCLUDE_TAGS` to exclude specific tags:

```bash
# Exclude @slow scenarios
CUCUMBER_EXCLUDE_TAGS=slow xcodebuild test \
  -project TodoApp.xcodeproj \
  -scheme TodoApp \
  -destination 'platform=macOS' 2>&1 | xcbeautify
```

The `@wip` tag is already excluded at compile time via the `tagFilter` override in `TodoUITests.swift`. Environment variable filters are merged with the compile-time filter.

### Run the PickleKit library tests

These are the framework's own unit tests (parser, runner, registry, etc.), separate from the TodoApp UI tests:

```bash
# From the repository root
swift test
```

## Project Structure

```
Example/TodoApp/
├── project.yml                    # xcodegen spec (committed, generates .xcodeproj)
├── README.md                      # This file
├── Sources/TodoApp/
│   ├── TodoApp.swift              # @main SwiftUI app entry point (Window scene, URL handler)
│   ├── ContentView.swift          # Todo list UI with accessibility identifiers
│   ├── TodoItem.swift             # Simple Identifiable model struct
│   ├── TodoStore.swift            # @Observable store: add, remove, update, clear, toggle
│   └── Info.plist                 # App configuration (URL scheme: todoapp://)
├── Tests/
│   └── TodoStoreTests.swift       # Unit tests for TodoStore (no UI dependency)
└── UITests/
    ├── Features/
    │   ├── todo_basics.feature        # CRUD, edit, and empty state (5 scenarios + 1 outline, @smoke)
    │   ├── todo_completion.feature    # Toggle completion (3 scenarios)
    │   └── todo_batch.feature         # Data tables, outlines, tags (4+1 scenarios, @smoke)
    └── TodoUITests.swift              # GherkinTestCase subclass + step definitions
```

Three targets: **TodoApp** (application), **TodoAppTests** (unit tests), **TodoAppUITests** (UI tests with PickleKit).

## How It Works

### Architecture

The app uses an `@Observable` `TodoStore` to manage todo state. The store is created as `@State` in the `App` struct and passed to `ContentView` as a plain `var` — SwiftUI's observation system tracks changes automatically. Extracting the store enables unit testing of all todo logic (`TodoStoreTests`) without touching the UI.

The app uses `Window` (not `WindowGroup`) as its scene type. This prevents duplicate windows from being created when handling `onOpenURL` calls — `WindowGroup` would open a new window for each URL event, which confuses XCUITest element queries.

### URL-scheme seeding

The app registers the `todoapp://` URL scheme via `Info.plist`. The `onOpenURL` handler in `TodoApp.swift` supports a `seed` action:

```
todoapp://seed?todos=["Buy groceries","Walk the dog"]
```

When this URL is opened, the handler calls `store.clear()` followed by `store.add(titles:)` to replace the entire todo list in a single operation. This allows UI tests to set up preconditions without clicking through the UI step-by-step — faster and less flaky than entering each item via the text field.

`Window` (rather than `WindowGroup`) is important here: a `WindowGroup` would create a new window each time a URL is opened, but `Window` reuses the existing one.

### End-to-end flow

1. **Feature files** (`.feature`) describe app behavior in Gherkin syntax
2. **`TodoUITests`** subclasses `GherkinTestCase` from PickleKit
3. At test suite load time, `GherkinTestCase` parses all `.feature` files from the `Features` folder
4. Each scenario is expanded (Scenario Outlines become concrete scenarios) and filtered by tags
5. Each surviving scenario becomes a dynamic XCTest method via ObjC runtime
6. When a test runs, `setUp()` launches the app (first scenario) or activates it (subsequent scenarios), `registerStepDefinitions()` registers step handlers, and the scenario's steps execute in order
7. Step handlers use `XCUIApplication` to interact with the app via accessibility identifiers
8. The `Background` step "the todo list is empty" clears all todos via the Clear All button, so each scenario starts from a clean state without relaunching the app

### Gherkin → Test mapping

A feature file like:

```gherkin
Scenario: Add a single todo
  When I enter "Buy groceries" in the text field
  And I tap the add button
  Then I should see "Buy groceries" at position 0
```

becomes a test method `test_Add_a_single_todo` that:
1. Calls the step handler for `I enter "([^"]*)" in the text field` with capture `"Buy groceries"`
2. Calls the step handler for `I tap the add button`
3. Calls the step handler for `I should see "([^"]*)" at position (\d+)` with captures `"Buy groceries"` and `"0"`

### Accessibility identifiers

The `ContentView` assigns identifiers to all interactive elements so XCUITest can find them reliably:

| Identifier | Element | Type |
|------------|---------|------|
| `todoTextField` | New todo text field | `textFields` |
| `addButton` | Add button | `buttons` |
| `emptyStateText` | "No todos yet" message | `staticTexts` |
| `todoCount` | Item count label | `staticTexts` |
| `todoToggle_N` | Checkbox for todo at index N | `checkBoxes` |
| `todoText_N` | Title text for todo at index N | `staticTexts` |
| `deleteButton_N` | Trash button for todo at index N | `buttons` |
| `editButton_N` | Edit button for todo at index N | `buttons` |
| `editTextField_N` | Inline edit text field for todo at index N | `textFields` |
| `clearAllButton` | Clear All button (visible when list non-empty) | `buttons` |

Index-based identifiers (`_0`, `_1`, ...) shift when items are added or removed, matching the current array order.

## Gherkin Features Demonstrated

| Feature File | Constructs | Tag |
|-------------|-----------|-----|
| `todo_basics.feature` | Background, 5 basic scenarios, step reuse | `@smoke` |
| `todo_completion.feature` | Toggle state assertions, multi-item state checks | — |
| `todo_batch.feature` | Data Tables, Scenario Outlines with Examples, `@wip` exclusion | `@smoke` |

### Construct examples

**Background** — runs before every scenario in the feature:
```gherkin
Background:
  Given the app is launched
  And the todo list is empty
```

**Data Table** — passed to step handler as `match.dataTable`:
```gherkin
When I add the following todos:
  | title            |
  | Buy groceries    |
  | Walk the dog     |
```

**Scenario Outline + Examples** — expanded into one concrete scenario per row:
```gherkin
Scenario Outline: Add todo with specific text
  When I enter "<title>" in the text field
  And I tap the add button
  Then I should see "<title>" at position 0

  Examples:
    | title          | count_text |
    | Morning run    | 1 item     |
    | Evening study  | 1 item     |
```

**Tag filtering** — `@wip` scenarios are excluded at compile time:
```gherkin
@wip
Scenario: Drag to reorder todos
  # Not yet implemented
```

## Writing New Tests

### Add a scenario to an existing feature

1. Add the scenario to a `.feature` file in `UITests/Features/`
2. If you use new step text, add a matching step definition in `TodoUITests.registerStepDefinitions()`
3. Rebuild and run tests

### Add a new feature file

1. Create `UITests/Features/my_new.feature`
2. It will be automatically picked up — `GherkinTestCase` parses all `.feature` files in the `Features` subdirectory
3. Add any new step definitions needed

### Add a step definition

In `TodoUITests.swift`, inside `registerStepDefinitions()`:

```swift
// Pattern is a regex. Capture groups become match.captures[0], [1], etc.
when("I do something with \"([^\"]*)\"") { match in
    let app = TodoUITests.app!
    let value = match.captures[0]
    // Use XCUIApplication APIs to interact with the app
    let element = app.buttons[value]
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    element.click()
}
```

Use `given()`, `when()`, `then()` for keyword-specific steps, or `step()` for keyword-agnostic matching.

## HTML Test Reports

PickleKit can generate Cucumber-style HTML reports with step-level results and timing.

### Report configuration by context

| Context | How to enable | Report path |
|---------|--------------|-------------|
| `swift test` (pickle-kit root) | `PICKLE_REPORT=1 swift test` | CWD or `PICKLE_REPORT_PATH` |
| `xcodebuild` / Xcode (TodoApp) | Scheme env var (already enabled) | Sandbox fallback only |

The `project.yml` scheme has `PICKLE_REPORT` enabled and `PICKLE_REPORT_PATH` **disabled**. `PICKLE_REPORT_PATH` is disabled because sandboxed UI test runners (`.xctrunner` bundles) cannot write to user-specified paths — the OS blocks it regardless of what path you set. PickleKit automatically falls back to `NSTemporaryDirectory()` inside the sandbox container, so the path variable is unnecessary.

To toggle `PICKLE_REPORT`, edit `project.yml` and set `isEnabled: true` or `isEnabled: false`, then re-run `xcodegen generate`. You can also toggle it in Xcode's scheme editor (Edit Scheme → Test → Arguments → Environment Variables).

### Enable via subclass override

Override the report properties directly in `TodoUITests.swift`:

```swift
override class var reportEnabled: Bool { true }
override class var reportOutputPath: String { "pickle-report.html" }
```

This approach always works regardless of how the tests are invoked. Note that `reportOutputPath` will still be subject to sandbox restrictions when running as a UI test — PickleKit will fall back to the temp directory if the path is not writable.

### Sandbox limitations

UI test runners (`*.xctrunner`) are sandboxed by the OS and cannot write to arbitrary paths like `/tmp` or the project source directory. This is enforced at the OS level for all `.xctrunner` bundles and cannot be bypassed. When the configured path is not writable, PickleKit falls back to the sandbox's temp directory. The actual path is printed to stderr (visible in xcodebuild output).

For this project, the report lands at:

```
~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html
```

Shell commands for working with the sandbox report:

```bash
# Open the report
open ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html

# Copy to current directory
cp ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html .

# Remove the report
rm ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html

# Remove all sandbox data (full cleanup)
rm -rf ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/
```

**Post-test report copy tip** — chain `xcodebuild` with a copy command to get the report in your working directory:

```bash
xcodebuild test -project TodoApp.xcodeproj -scheme TodoApp -destination 'platform=macOS' 2>&1 | xcbeautify \
  && cp ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html . \
  && open pickle-report.html
```

### Report content

The report is a self-contained HTML file with:
- Summary header with feature, scenario, and step counts
- Per-feature sections with collapsible scenarios
- Per-step detail with keyword, text, timing, and error messages
- Interactive expand/collapse and status filtering

Failed scenarios are expanded by default.

## Key Design Patterns

| Pattern | Why |
|---------|-----|
| `@Observable TodoStore` | Extracted store for testability. `@State` in `App`, plain `var` in `ContentView`. Enables `TodoStoreTests` without UI. |
| `Window` instead of `WindowGroup` | Prevents duplicate windows from URL handling. `WindowGroup` creates a new window per `onOpenURL` event. |
| `todoapp://seed` URL scheme | Bypasses UI for fast, deterministic test setup. Calls `store.clear()` + `store.add(titles:)` in one step. |
| `TodoAppTests` (unit tests) | Tests store logic (add, remove, update, clear, toggle) independently of the UI. |
| `nonisolated(unsafe) static var app` | `XCUIApplication` isn't `Sendable`, but `StepHandler` requires `@Sendable`. Safe because XCUITest runs sequentially. |
| `waitForExistence(timeout: 5)` on all queries | Prevents flaky tests from race conditions between UI updates and assertions. |
| App reuse across scenarios | `setUp()` launches once, then activates. Clear All button resets state between scenarios for faster execution. |
| Index-based identifiers (`todoText_0`) | Deterministic IDs from `ForEach(Array(todos.enumerated()))`. Shift with the array. |
| Local package dependency (`path: ../..`) | `project.yml` references PickleKit from the repo root, no remote fetch needed. |

## Performance Notes

The test suite reuses the app process across scenarios instead of relaunching for each one. `setUp()` calls `launch()` only for the first scenario; subsequent scenarios call `activate()` to bring the existing process to the foreground. State is reset between scenarios by the "the todo list is empty" Background step, which taps the Clear All button to remove all todos.

This avoids the overhead of `XCUIApplication.launch()` per scenario (~8-10s saved per scenario on typical hardware). Expected total run time is roughly 5-8 seconds per scenario vs ~13 seconds with a full relaunch.

## Troubleshooting

### "xcodegen: command not found"

Install it: `brew install xcodegen`

### "xcode-select: error: tool 'xcodebuild' requires Xcode"

Point to Xcode (not just Command Line Tools):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Tests fail with "Failed to parse feature files"

The feature files must be bundled as a folder resource in the test target. Re-run `xcodegen generate` and verify the `UITests/Features` folder appears under the `TodoAppUITests` target in Xcode's project navigator.

### App launches but tests can't find elements

Check that accessibility identifiers in `ContentView.swift` match the strings used in step definitions. Use Xcode's Accessibility Inspector (`Xcode > Open Developer Tool > Accessibility Inspector`) to inspect the running app's element hierarchy.

### "No scenario found for test_..."

The scenario name was sanitized differently than expected. Check the test navigator in Xcode to see the actual generated method names. Non-alphanumeric characters become underscores, and consecutive underscores are collapsed.

### Tests crash or behave unexpectedly after changing feature files

Xcode may cache stale test method metadata. Clean the build and package caches:

1. In Xcode: **Product → Clean Build Folder** (Shift+Cmd+K)
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/TodoApp-*`
3. Re-run `xcodegen generate` and rebuild
