# CucumberAndApples

A standalone Swift Cucumber/BDD testing framework with zero external dependencies. Parse Gherkin `.feature` files, register step definitions with regex patterns, and run scenarios — all integrated with XCTest.

## Installation

Add CucumberAndApples to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<user>/cucumber-and-apples.git", from: "0.1.0"),
],
targets: [
    .testTarget(
        name: "MyTests",
        dependencies: ["CucumberAndApples"],
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
import CucumberAndApples

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

CucumberAndApples supports the core Gherkin syntax:

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

## Programmatic Usage

You can use the parser and runner directly without `GherkinTestCase`:

```swift
import CucumberAndApples

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
Sources/CucumberAndApples/
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

## License

MIT
