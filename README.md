# PickleKit

[![CI](https://github.com/nycjv321/pickle-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/nycjv321/pickle-kit/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/platform-Apple%20Platforms-blue)](https://github.com/nycjv321/pickle-kit)
[![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Claude](https://img.shields.io/badge/Built%20with-Claude-blueviolet)](https://claude.ai)

A standalone Swift Cucumber/BDD testing framework with zero external dependencies. Parse Gherkin `.feature` files, register step definitions with regex patterns, and run scenarios — all integrated with XCTest.

## Installation

Add PickleKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<user>/pickle-kit.git", from: "0.1.0"),
],
targets: [
    .testTarget(
        name: "MyTests",
        dependencies: ["PickleKit"],
        resources: [.copy("Features")]
    ),
]
```

## Quick Start

### 1. Write a feature file

```gherkin
# Tests/MyTests/Features/calculator.feature
Feature: Calculator

  Scenario: Addition
    Given I have the number 5
    When I add 3
    Then the result should be 8
```

### 2. Create a test class

```swift
import XCTest
import PickleKit

final class CalculatorTests: GherkinTestCase {
    override class var featureSubdirectory: String? { "Features" }

    override func registerStepDefinitions() {
        var result = 0

        given("I have the number (\\d+)") { match in
            result = Int(match.captures[0])!
        }

        when("I add (\\d+)") { match in
            result += Int(match.captures[0])!
        }

        then("the result should be (\\d+)") { match in
            let expected = Int(match.captures[0])!
            XCTAssertEqual(result, expected)
        }
    }
}
```

### 3. Run tests

```bash
swift test
```

Each scenario appears as a separate test in Xcode's test navigator.

## Gherkin Support

PickleKit supports the core Gherkin syntax:

### Keywords

`Feature`, `Background`, `Scenario`, `Scenario Outline` / `Scenario Template`, `Examples` / `Scenarios`, `Given`, `When`, `Then`, `And`, `But`

### Tags

```gherkin
@smoke
Feature: Tagged feature

  @fast
  Scenario: Quick test
    Given something
    Then it works
```

### Data Tables

```gherkin
Scenario: User list
  Given the following users exist:
    | name  | role  |
    | Alice | admin |
    | Bob   | user  |
```

Access in step handlers via `match.dataTable`:

```swift
given("the following users exist:") { match in
    let users = match.dataTable!.asDictionaries
    // [["name": "Alice", "role": "admin"], ["name": "Bob", "role": "user"]]
}
```

### Doc Strings

```gherkin
Scenario: API response
  Given the API returns:
    """
    {"status": "ok", "count": 42}
    """
```

Access via `match.docString`:

```swift
given("the API returns:") { match in
    let json = match.docString!
}
```

### Scenario Outlines

```gherkin
Scenario Outline: Arithmetic
  Given I have <start> items
  When I remove <count>
  Then I have <remaining> items

  Examples:
    | start | count | remaining |
    | 10    | 3     | 7         |
    | 5     | 2     | 3         |
```

Outlines are automatically expanded into concrete scenarios. Each row becomes a separate test.

### Backgrounds

```gherkin
Feature: Shopping
  Background:
    Given I have an empty cart

  Scenario: Add item
    When I add "Apple"
    Then the cart has 1 item
```

Background steps run before every scenario in the feature.

### Comments

Lines starting with `#` are ignored.

## Step Registration

Step patterns are regex strings. Capture groups become `match.captures`:

```swift
// Exact match
given("I am logged in") { _ in /* ... */ }

// Capture groups
when("I add (\\d+) items? of \"([^\"]*)\"") { match in
    let count = Int(match.captures[0])!
    let item = match.captures[1]
}

// Keyword-agnostic (matches Given, When, Then, And, But)
step("the count is (\\d+)") { match in /* ... */ }
```

Patterns are anchored — they must match the entire step text.

## Tag Filtering

Filter scenarios by tags in your test class:

```swift
final class SmokeTests: GherkinTestCase {
    override class var tagFilter: TagFilter? {
        TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
    }
}
```

- **includeTags**: Only run scenarios matching at least one tag (empty = include all)
- **excludeTags**: Skip scenarios matching any tag (takes priority over include)

Tags from the feature level and scenario level are combined.

## Filtering Scenarios

There are three ways to filter which scenarios run:

### 1. Name-based filtering with `swift test --filter`

Use Swift's built-in test filtering to match test names:

```bash
swift test --filter CalculatorTests
swift test --filter test_Addition
```

### 2. Compile-time tag filtering with `tagFilter`

Override `tagFilter` in your test class (shown above in [Tag Filtering](#tag-filtering)).

### 3. CLI tag filtering with environment variables

Filter scenarios at runtime without changing code:

| Variable | Purpose | Format |
|----------|---------|--------|
| `CUCUMBER_TAGS` | Include only scenarios matching these tags | Comma-separated: `smoke,critical` |
| `CUCUMBER_EXCLUDE_TAGS` | Exclude scenarios matching these tags | Comma-separated: `wip,manual` |

```bash
# Run only smoke-tagged scenarios
CUCUMBER_TAGS=smoke swift test

# Exclude work-in-progress and slow scenarios
CUCUMBER_EXCLUDE_TAGS=wip,slow swift test

# Combine both
CUCUMBER_TAGS=smoke CUCUMBER_EXCLUDE_TAGS=wip swift test
```

Environment variable tags are **merged** with any compile-time `tagFilter` override. Both include and exclude sets are unioned.

## HTML Test Reports

PickleKit can generate Cucumber-style HTML reports with per-step results, timing, and status filtering.

### Generate a report

Set the `PICKLE_REPORT` environment variable when running tests:

```bash
PICKLE_REPORT=1 swift test
```

This writes `pickle-report.html` to the current directory. To customize the output path:

```bash
PICKLE_REPORT=1 PICKLE_REPORT_PATH=build/report.html swift test
```

Intermediate directories are created automatically — `build/report.html` works even if `build/` doesn't exist.

The report includes:

- **Summary header** — feature, scenario, and step counts with color-coded progress bars
- **Per-feature sections** — collapsible scenarios with tags, duration, and status badges
- **Per-step detail** — keyword, text, timing, and error messages for failed steps
- **Interactive controls** — expand/collapse all, filter by passed/failed status

Failed scenarios are expanded by default; passing ones are collapsed.

### Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PICKLE_REPORT` | *(unset = off)* | Set to any value to enable report generation |
| `PICKLE_REPORT_PATH` | `pickle-report.html` | Output file path (ineffective for sandboxed UI test runners — see note below) |

Subclasses of `GherkinTestCase` can also override these as class properties for compile-time control:

```swift
final class MyTests: GherkinTestCase {
    override class var reportEnabled: Bool { true }
    override class var reportOutputPath: String { "build/my-report.html" }
}
```

### Reports with xcodebuild

`xcodebuild` does not pass shell environment variables to the test runner process. For Xcode projects (including the Example TodoApp), use one of these approaches:

**Subclass override (recommended for CI):**

```swift
final class MyTests: GherkinTestCase {
    override class var reportEnabled: Bool { true }
    override class var reportOutputPath: String { "pickle-report.html" }
}
```

**Scheme environment variables (Xcode GUI):**

1. Edit your scheme → Test → Arguments → Environment Variables
2. Add `PICKLE_REPORT` = `1` and optionally `PICKLE_REPORT_PATH`
3. These are stored in the `.xcscheme` file and passed to the test runner

If using xcodegen, add to `project.yml`:

```yaml
schemes:
  MyScheme:
    test:
      environmentVariables:
        - variable: PICKLE_REPORT
          value: "1"
          isEnabled: true
```

**Note:** UI test runners (`.xctrunner` bundles) are sandboxed and cannot write to arbitrary paths. `PICKLE_REPORT_PATH` is ineffective in this context — the OS blocks writes to user-specified paths regardless. PickleKit falls back to `NSTemporaryDirectory()` inside the sandbox container (`~/Library/Containers/<bundle-id>.xctrunner/Data/tmp/`). The actual path is printed to stderr.

### Programmatic report generation

You can generate reports without XCTest using the `HTMLReportGenerator` directly:

```swift
import PickleKit

let result = TestRunResult(
    featureResults: [featureResult],
    startTime: startTime,
    endTime: Date()
)

let generator = HTMLReportGenerator()
try generator.write(result: result, to: "report.html")
```

Or collect results incrementally with `ReportResultCollector`:

```swift
let collector = ReportResultCollector()

// After each scenario runs:
collector.record(
    scenarioResult: result,
    featureName: feature.name,
    featureTags: feature.tags,
    sourceFile: feature.sourceFile
)

// When finished:
let testRunResult = collector.buildTestRunResult()
let generator = HTMLReportGenerator()
try generator.write(result: testRunResult, to: "report.html")
```

## Programmatic Usage

You can use the parser and runner directly without `GherkinTestCase`:

```swift
import PickleKit

// Parse
let parser = GherkinParser()
let feature = try parser.parse(source: gherkinText)

// Or from a file
let feature = try parser.parseFile(at: "/path/to/test.feature")

// Expand outlines
let expander = OutlineExpander()
let expanded = expander.expand(feature)

// Register steps
let registry = StepRegistry()
registry.given("I have (\\d+) items") { match in /* ... */ }

// Run
let runner = ScenarioRunner(registry: registry)
let result = try await runner.run(feature: expanded)

print("Passed: \(result.passedCount), Failed: \(result.failedCount)")
```

## Architecture

```
Sources/PickleKit/
├── AST/                    # Feature, Scenario, Step, DataTable model types
├── Parser/                 # GherkinParser (state machine), OutlineExpander
├── Report/                 # HTML report generation (StepResult, HTMLReportGenerator, ReportResultCollector)
├── Runner/                 # StepRegistry, ScenarioRunner, TagFilter
└── XCTestBridge/           # GherkinTestCase (XCTest integration)
```

All types are `Sendable`. Step handlers are `async throws`.

## Requirements

- Swift 5.9+
- macOS 14+ / iOS 17+ / tvOS 17+ / watchOS 10+
- XCTest bridge requires ObjC runtime (Apple platforms)

## Example: TodoApp with XCUITest

The [`Example/TodoApp`](Example/TodoApp) directory contains a complete macOS SwiftUI todo app that demonstrates PickleKit with XCUITest. It includes:

- **3 targets**: TodoApp (application), TodoAppTests (unit tests for `TodoStore`), TodoAppUITests (Gherkin UI tests)
- **3 feature files** covering CRUD, completion toggling, data tables, scenario outlines, and tag filtering
- **Unit tests** for the `@Observable TodoStore` — verifying add, remove, update, clear, and toggle without UI
- **Step definitions** that drive `XCUIApplication` via accessibility identifiers
- **URL-scheme seeding** (`todoapp://seed`) for fast, deterministic test setup
- **xcodegen** project spec (`project.yml`) — run `xcodegen generate` to create the Xcode project

See [`Example/TodoApp/README.md`](Example/TodoApp/README.md) for setup and usage, and [`docs/TESTING.md`](docs/TESTING.md) for test design philosophy and UI test best practices.

## License

MIT
