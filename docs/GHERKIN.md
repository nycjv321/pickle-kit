# Gherkin Reference

This document covers PickleKit's Gherkin syntax support, step registration, tag filtering, scenario filtering, and programmatic usage.

## Gherkin Support

PickleKit supports the core Gherkin syntax.

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

## Step Definition Types

For larger test suites, organize step definitions into separate types by domain. Types conforming to the `StepDefinitions` protocol declare steps as stored properties, which are automatically discovered via Swift's `Mirror` API.

### Declaring step definition types

```swift
struct CartSteps: StepDefinitions {
    nonisolated(unsafe) static var cart: [String] = []
    init() { Self.cart = [] }  // reset per-scenario

    let emptyCart: StepDefinition = .given("I have an empty cart") { _ in
        Self.cart = []
    }

    let addItem: StepDefinition = .when("I add \"([^\"]*)\" to the cart") { match in
        Self.cart.append(match.captures[0])
    }

    let cartCount: StepDefinition = .then("the cart should contain (\\d+) items?") { match in
        XCTAssertEqual(Self.cart.count, Int(match.captures[0])!)
    }
}
```

Key points:
- Steps must be stored `let` properties (`StepDefinition` type). Computed properties are invisible to `Mirror`.
- Use `nonisolated(unsafe) static var` for state shared across steps within a scenario.
- `init()` is called per-scenario — use it to reset state.
- `[StepDefinition]` array properties are also discovered (each element registered individually).
- Override `register(in:)` to bypass Mirror and register manually.

### Using step definition types in a test class

List your types in `stepDefinitionTypes`:

```swift
final class ShoppingTests: GherkinTestCase {
    override class var featureSubdirectory: String? { "Features" }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [CartSteps.self, PaymentSteps.self, AccountSteps.self]
    }
}
```

Type-based providers are registered before `registerStepDefinitions()`, so both approaches coexist in the same test class. Ambiguity detection works across both sources.

### Filtering step definition types at runtime

Set `CUCUMBER_STEP_DEFINITIONS` to a comma-separated list of type names to restrict which types are registered:

```bash
# Only register CartSteps and PaymentSteps (others are skipped)
CUCUMBER_STEP_DEFINITIONS="CartSteps,PaymentSteps" swift test
```

This filters from the compiled `stepDefinitionTypes` list — all types must still be compiled into the test target. Inline steps from `registerStepDefinitions()` are unaffected by this filter.

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

// Register steps (inline)
let registry = StepRegistry()
registry.given("I have (\\d+) items") { match in /* ... */ }

// Or register from StepDefinitions types
let provider = CartSteps()
provider.register(in: registry)

// Run
let runner = ScenarioRunner(registry: registry)
let result = try await runner.run(feature: expanded)

print("Passed: \(result.passedCount), Failed: \(result.failedCount)")
```
