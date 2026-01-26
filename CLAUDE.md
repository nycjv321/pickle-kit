# Claude Code Instructions for CucumberAndApples

## Project Overview

CucumberAndApples is a standalone Swift Cucumber/BDD testing framework. It provides a Gherkin parser, step registry, scenario runner, and XCTest bridge with zero external dependencies.

## Architecture

### Package Structure

```
Sources/CucumberAndApples/
├── AST/
│   └── GherkinAST.swift          # All model types (Feature, Scenario, Step, etc.)
├── Parser/
│   ├── GherkinParser.swift       # Line-by-line state machine Gherkin parser
│   └── OutlineExpander.swift     # Scenario Outline → concrete Scenario expansion
├── Runner/
│   ├── StepRegistry.swift        # Regex pattern → async closure mapping
│   ├── ScenarioRunner.swift      # Executes scenarios against registry
│   └── TagFilter.swift           # Include/exclude tag filtering
└── XCTestBridge/
    └── GherkinTestCase.swift     # XCTestCase subclass with dynamic test generation
```

### Key Design Decisions

- **Zero dependencies** — only Foundation and XCTest (implicit for test targets)
- **All AST types are `Sendable` and `Equatable`** — value types throughout
- **`StepRegistry` is instance-based** (not singleton) for testability
- **`StepHandler` is `@Sendable (StepMatch) async throws -> Void`** — async/await compatible
- **`GherkinTestCase` uses ObjC runtime** (`class_addMethod`, `unsafeBitCast`) to create dynamic test methods since `XCTestCase.init(selector:)` is unavailable in Swift
- **`GherkinParser` is a line-by-line state machine** with states: idle → inFeature → inBackground/inScenario/inOutline/inExamples/inDocString
- **Conditional compilation** — `GherkinTestCase` is wrapped in `#if canImport(XCTest) && canImport(ObjectiveC)`

### Platforms

macOS 14+, iOS 17+, tvOS 17+, watchOS 10+

## Code Organization

| File | Purpose |
|------|---------|
| `GherkinAST.swift` | Feature, ScenarioDefinition, Scenario, ScenarioOutline, Background, Step, StepKeyword, DataTable, ExamplesTable |
| `GherkinParser.swift` | Parses Gherkin source text/files/bundles into Feature AST |
| `OutlineExpander.swift` | Expands ScenarioOutline + Examples into concrete Scenarios |
| `StepRegistry.swift` | StepMatch, StepHandler, StepRegistryError, StepRegistry |
| `ScenarioRunner.swift` | ScenarioRunnerError, ScenarioResult, FeatureResult, ScenarioRunner |
| `TagFilter.swift` | Include/exclude filtering on tag arrays |
| `GherkinTestCase.swift` | XCTestCase subclass, dynamic test suite via ObjC runtime |

## Testing

```bash
swift test                              # Run all tests
swift test --filter ParserTests         # Parser tests only
swift test --filter StepRegistryTests   # Registry tests only
swift test --filter ScenarioRunnerTests # Runner tests only
```

### Test Structure

```
Tests/CucumberAndApplesTests/
├── ParserTests.swift           # Gherkin parsing: features, scenarios, steps, tables, doc strings, tags, errors
├── OutlineExpanderTests.swift  # Outline expansion: substitution, naming, tag combination, edge cases
├── StepRegistryTests.swift     # Pattern matching: regex captures, ambiguity, anchoring, data passthrough
├── ScenarioRunnerTests.swift   # Execution: passing/failing scenarios, backgrounds, tag filtering, captures
├── TagFilterTests.swift        # Include/exclude logic, priority, edge cases
└── Fixtures/                   # .feature files loaded via Bundle.module
    ├── basic.feature
    ├── with_background.feature
    ├── with_outline.feature
    ├── with_tables.feature
    ├── with_docstrings.feature
    └── with_tags.feature
```

Fixtures are copied into the test bundle via `resources: [.copy("Fixtures")]` in Package.swift. Access them with `Bundle.module.url(forResource:withExtension:subdirectory:"Fixtures")`.

### Test Patterns

```swift
// Parser tests load fixtures
private func loadFixture(_ name: String) throws -> Feature {
    let url = Bundle.module.url(forResource: name, withExtension: "feature", subdirectory: "Fixtures")!
    let source = try String(contentsOf: url, encoding: .utf8)
    return try parser.parse(source: source, fileName: "\(name).feature")
}

// Runner tests use mock step handlers
registry.given("a setup") { _ in log.append("given") }
let result = try await runner.run(scenario: scenario)
XCTAssertTrue(result.passed)

// Registry tests check matching
let result = try registry.match(step)
XCTAssertEqual(result?.match.captures, ["42", "apples"])
```

## Common Tasks

### Adding a new Gherkin keyword

1. If it's a step keyword, add to `StepKeyword` enum in `GherkinAST.swift`
2. Update `parseStepKeyword()` in `GherkinParser.swift`
3. Add test coverage in `ParserTests.swift`

### Adding a new AST node type

1. Add the struct/enum to `GherkinAST.swift` — make it `public`, `Sendable`, `Equatable`
2. Update `GherkinParser` to populate it during parsing
3. Update `OutlineExpander` if it participates in outline expansion
4. Add tests

### Adding parser support for a new construct

1. Add a new `ParseMode` case if it requires state tracking
2. Add a handler method (`handleXxxKeyword`)
3. Update `processLine()` to detect the keyword
4. Update `finalizeCurrentScenario()` / `finalizeState()` if needed
5. Create a fixture `.feature` file and add parser tests

### Modifying step matching behavior

1. Changes go in `StepRegistry.swift`
2. The `match(_ step:)` method does full-string anchored regex matching
3. Patterns are stored as `^pattern$` — modify `register()` to change anchoring
4. Test with `StepRegistryTests`

## Key Patterns

```swift
// Parse from string
let parser = GherkinParser()
let feature = try parser.parse(source: gherkinText, fileName: "test.feature")

// Parse from bundle
let features = try parser.parseBundle(bundle: .module, subdirectory: "Features")

// Expand outlines
let expander = OutlineExpander()
let expanded = expander.expand(feature)

// Register and run
let registry = StepRegistry()
registry.given("pattern with (\\d+) captures") { match in
    let value = match.captures[0]
    let table = match.dataTable     // Optional DataTable
    let doc = match.docString       // Optional String
}

let runner = ScenarioRunner(registry: registry)
let result = try await runner.run(feature: expanded, tagFilter: TagFilter(excludeTags: ["wip"]))
```

## CI/CD

### GitHub Actions

- **ci.yml** — Runs on push to `main`/`feature/*` and PRs to `main`. Tests with code coverage, release build validation.
- **release.yml** — Triggered after successful CI on `main`. Uses release-please for changelog and version tagging.

### Running CI locally

```bash
swift build              # Debug build
swift test               # Run tests
swift build -c release   # Release build
```

## Concurrency Notes

- All AST types are `Sendable` value types
- `StepHandler` is `@Sendable ... async throws` — handlers run in async context
- `StepRegistry` is `@unchecked Sendable` — not thread-safe for concurrent registration, but safe for concurrent matching after setup
- `ScenarioRunner` is `Sendable` — safe to use from any context
- `GherkinTestCase` runs scenarios with `Task` + `waitForExpectations` to bridge XCTest's sync test methods with async step handlers
- Test warnings about `SendableClosureCaptures` in test files are expected (test-only mutable state in closures)
