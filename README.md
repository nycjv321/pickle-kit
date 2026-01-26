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

- **3 feature files** covering CRUD, completion toggling, data tables, scenario outlines, and tag filtering
- **Step definitions** that drive `XCUIApplication` via accessibility identifiers
- **xcodegen** project spec (`project.yml`) — run `xcodegen generate` to create the Xcode project

See [`Example/TodoApp/README.md`](Example/TodoApp/README.md) for setup and usage instructions.

## License

MIT
