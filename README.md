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

## Why PickleKit

Before PickleKit, using Cucumber-style BDD in Swift required external toolchains — Ruby (via Cucumber), Java (via Karate), or CocoaPods-based frameworks. PickleKit provides a zero-dependency Swift-native Cucumber framework that integrates directly with XCTest. No Gemfile, no Podfile, no build plugins — just a Swift package dependency.

## Gherkin Support

PickleKit supports the core Gherkin syntax:

- **Keywords** — `Feature`, `Background`, `Scenario`, `Scenario Outline`, `Given`, `When`, `Then`, `And`, `But`
- **Tags** — `@smoke`, `@wip`, etc. at feature and scenario level
- **Data Tables** — pipe-delimited tables accessible via `match.dataTable`
- **Doc Strings** — triple-quoted blocks accessible via `match.docString`
- **Scenario Outlines** — parameterized scenarios expanded from `Examples` tables
- **Backgrounds** — shared setup steps that run before every scenario
- **Comments** — lines starting with `#`

See [Gherkin Reference](docs/GHERKIN.md) for full syntax, step registration, tag filtering, and programmatic usage.

## HTML Test Reports

Generate Cucumber-style HTML reports with per-step results, timing, and status filtering:

```bash
PICKLE_REPORT=1 swift test
```

The report includes summary counts, per-feature sections with collapsible scenarios, per-step timing and error details, and interactive filtering controls.

See [Report Configuration](docs/REPORTING.md) for customization, xcodebuild integration, and programmatic generation.

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

## Testing

PickleKit follows the testing trophy model: invest most in integration tests, use unit tests for pure logic, and use Gherkin-driven E2E tests for critical user flows.

```bash
swift test                           # Run all PickleKit tests
swift test --filter ParserTests      # Run a specific test suite
PICKLE_REPORT=1 swift test           # Run tests + generate HTML report
```

See [Testing Guide](docs/TESTING.md) for test design philosophy, BDD rationale, and UI test best practices.

## Continuous Integration

PickleKit has a fully functioning CI pipeline via GitHub Actions that runs on every push and pull request. The pipeline has three jobs:

```
unit-tests ──┬──> ui-tests
             └──> build
```

Unit tests gate both the UI test and release build jobs, which run in parallel. See [Testing Guide](docs/TESTING.md) for CI configuration details and [Release Process](docs/RELEASE.md) for the automated release pipeline.

## Example: TodoApp with XCUITest

The [`Example/TodoApp`](Example/TodoApp) directory contains a complete macOS SwiftUI todo app that demonstrates PickleKit with XCUITest. It includes:

- **3 targets**: TodoApp (application), TodoAppTests (unit tests for `TodoStore`), TodoAppUITests (Gherkin UI tests)
- **3 feature files** covering CRUD, completion toggling, data tables, scenario outlines, and tag filtering
- **Unit tests** for the `@Observable TodoStore` — verifying add, remove, update, clear, and toggle without UI
- **Step definitions** that drive `XCUIApplication` via accessibility identifiers
- **URL-scheme seeding** (`todoapp://seed`) for fast, deterministic test setup
- **xcodegen** project spec (`project.yml`) — run `xcodegen generate` to create the Xcode project

See [`Example/TodoApp/README.md`](Example/TodoApp/README.md) for setup and usage.

## License

MIT
