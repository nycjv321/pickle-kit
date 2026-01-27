# Claude Code Instructions for PickleKit

## Project Overview

PickleKit is a standalone Swift Cucumber/BDD testing framework. It provides a Gherkin parser, step registry, scenario runner, and XCTest bridge with zero external dependencies.

## Architecture

### Package Structure

```
Sources/PickleKit/
├── AST/
│   └── GherkinAST.swift          # All model types (Feature, Scenario, Step, etc.)
├── Parser/
│   ├── GherkinParser.swift       # Line-by-line state machine Gherkin parser
│   └── OutlineExpander.swift     # Scenario Outline → concrete Scenario expansion
├── Report/
│   ├── StepResult.swift          # StepStatus enum + StepResult per-step execution data
│   ├── TestRunResult.swift       # Aggregated test run results with computed counts
│   ├── HTMLReportGenerator.swift # Self-contained HTML report with inline CSS/JS
│   └── ReportResultCollector.swift # Thread-safe result accumulator (OSAllocatedUnfairLock)
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
- **`GherkinTestCase` uses ObjC runtime** (`class_addMethod`, `unsafeBitCast`) to create dynamic test methods since `XCTestCase.init(selector:)` is unavailable in Swift. **Important:** `XCTestSuite(forTestCaseClass:)` must be called *after* all `class_addMethod` calls — it discovers `test_*` methods via ObjC reflection. Creating the suite first and then adding methods produces duplicate entries that can crash Xcode's result bundle builder.
- **`DataTable.dataRows` always drops the first row** — it assumes the first row is a header. All data tables used with `dataRows` must include an explicit header row (e.g., `| title |`). Tables without a header will silently lose the first data row.
- **Per-class scenario maps** — `GherkinTestCase` stores scenario data in a dictionary keyed by `ObjectIdentifier(self)` so multiple subclasses (and the base class itself when discovered by XCTest) don't overwrite each other's data
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
| `GherkinTestCase.swift` | XCTestCase subclass, dynamic test suite via ObjC runtime, report integration |
| `StepResult.swift` | StepStatus enum, StepResult per-step execution data |
| `TestRunResult.swift` | Aggregated test run result with feature/scenario/step counts |
| `HTMLReportGenerator.swift` | Self-contained HTML report generator with inline CSS/JS |
| `ReportResultCollector.swift` | Thread-safe result accumulator using OSAllocatedUnfairLock |
| `GherkinIntegrationTests.swift` | GherkinTestCase subclass running all fixture features (enables `PICKLE_REPORT=1 swift test`) |

## Testing

```bash
swift test                                     # Run all tests
swift test --filter ParserTests                # Parser tests only
swift test --filter StepRegistryTests          # Registry tests only
swift test --filter ScenarioRunnerTests        # Runner tests only
swift test --filter StepResultTests            # Step result/timing tests
swift test --filter HTMLReportGeneratorTests    # Report generation tests
swift test --filter GherkinIntegrationTests    # Full pipeline integration tests
PICKLE_REPORT=1 swift test                     # Run tests + generate HTML report
```

### Test Structure

```
Tests/PickleKitTests/
├── ParserTests.swift              # Gherkin parsing: features, scenarios, steps, tables, doc strings, tags, errors
├── OutlineExpanderTests.swift     # Outline expansion: substitution, naming, tag combination, edge cases
├── StepRegistryTests.swift        # Pattern matching: regex captures, ambiguity, anchoring, data passthrough
├── ScenarioRunnerTests.swift      # Execution: passing/failing scenarios, backgrounds, tag filtering, captures
├── TagFilterTests.swift           # Include/exclude logic, priority, edge cases
├── StepResultTests.swift          # Step-level results: status, timing, tags, undefined/skipped, backward compat
├── HTMLReportGeneratorTests.swift # HTML generation: structure, counts, CSS classes, escaping, collector, aggregations
├── GherkinIntegrationTests.swift  # Full pipeline: GherkinTestCase subclass running all fixture features
└── Fixtures/                      # .feature files loaded via Bundle.module
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

// CLI tag filtering via environment variables (merged with compile-time tagFilter)
// CUCUMBER_TAGS=smoke,critical swift test
// CUCUMBER_EXCLUDE_TAGS=wip,slow swift test
let envFilter = TagFilter.fromEnvironment()        // reads CUCUMBER_TAGS / CUCUMBER_EXCLUDE_TAGS
let merged = existingFilter.merging(envFilter!)     // unions include and exclude sets
```

## HTML Report Generation

PickleKit generates Cucumber-style HTML reports with step-level results, timing, and interactive filtering.

### How It Works

1. `ScenarioRunner.run()` captures per-step timing and builds `[StepResult]` arrays — each step gets `.passed`, `.failed`, `.undefined`, or `.skipped` status
2. `GherkinTestCase.executeScenario()` records each `ScenarioResult` into a shared `ReportResultCollector` (when `reportEnabled`)
3. Reports are written via two mechanisms: `class func tearDown()` (after each `GherkinTestCase` subclass finishes) and an `atexit` handler (process exit). The `tearDown` approach ensures reports work under `xcodebuild` where the test runner may be killed before `atexit` fires
4. `HTMLReportGenerator.write(result:to:)` creates intermediate directories automatically — `build/report.html` works even if `build/` doesn't exist

### Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `PICKLE_REPORT` | *(unset = off)* | Set to any value to enable |
| `PICKLE_REPORT_PATH` | `pickle-report.html` | Output file path (ineffective for sandboxed UI test runners) |

```bash
PICKLE_REPORT=1 swift test
PICKLE_REPORT=1 PICKLE_REPORT_PATH=build/report.html swift test
```

Subclasses can override `reportEnabled` / `reportOutputPath` class properties for compile-time control.

### Key Types

| Type | Purpose |
|------|---------|
| `StepStatus` | Enum: `.passed`, `.failed`, `.skipped`, `.undefined` |
| `StepResult` | Per-step data: keyword, text, status, duration, error, sourceLine |
| `TestRunResult` | Aggregated results with computed counts for features/scenarios/steps |
| `HTMLReportGenerator` | Generates self-contained HTML with inline CSS/JS |
| `ReportResultCollector` | Thread-safe accumulator using `OSAllocatedUnfairLock` |

### Enriched Result Types

`ScenarioResult` and `FeatureResult` have additional fields (all with defaults for backward compatibility):

- **ScenarioResult**: `tags: [String]`, `stepResults: [StepResult]`, `duration: TimeInterval`
- **FeatureResult**: `tags: [String]`, `sourceFile: String?`, `duration: TimeInterval`, plus computed step counts (`totalStepCount`, `passedStepCount`, `failedStepCount`, `skippedStepCount`, `undefinedStepCount`)

### Programmatic Usage

```swift
// Direct generation from known results
let result = TestRunResult(featureResults: [...], startTime: start, endTime: Date())
let generator = HTMLReportGenerator()
try generator.write(result: result, to: "report.html")

// Incremental collection
let collector = ReportResultCollector()
collector.record(scenarioResult: result, featureName: "Login", featureTags: ["auth"])
let testRun = collector.buildTestRunResult()
```

## CI/CD

### GitHub Actions

- **ci.yml** — Runs on push to `main`/`feature/*` and PRs to `main`. Tests with code coverage via xcbeautify, publishes JUnit report via dorny/test-reporter, then validates release build. Requires `permissions: checks: write` for test reporting.
- **release.yml** — Triggered after successful CI on `main`. Uses release-please for changelog and version tagging.

### Test Reporting

CI generates `junit.xml` via `xcbeautify --report junit --report-path .` (not `--xunit-output`, which doesn't produce files on macOS). The report is published by `dorny/test-reporter@v1` with `fail-on-error: false`.

### Release Process

See [docs/RELEASE.md](docs/RELEASE.md) for full documentation on conventional commits, release-please, and troubleshooting.

### Running CI locally

```bash
swift build                                            # Debug build
swift test                                             # Run tests
swift build -c release                                 # Release build
PICKLE_REPORT=1 swift test                             # Run tests + generate HTML report
PICKLE_REPORT=1 PICKLE_REPORT_PATH=build/report.html swift test  # Custom report path
```

## Example App

The `Example/TodoApp/` directory contains a macOS SwiftUI todo app demonstrating PickleKit with XCUITest.

### Structure

```
Example/TodoApp/
├── project.yml                    # xcodegen spec (generates .xcodeproj)
├── Sources/TodoApp/               # SwiftUI app (TodoApp.swift, ContentView.swift, TodoItem.swift)
└── UITests/
    ├── Features/                  # 3 Gherkin feature files
    └── TodoUITests.swift          # GherkinTestCase subclass + step definitions
```

### Running

```bash
cd Example/TodoApp
xcodegen generate
xcodebuild test -project TodoApp.xcodeproj -scheme TodoApp -destination 'platform=macOS' 2>&1 | xcbeautify
```

### HTML Reports with xcodebuild

`xcodebuild` does **not** pass shell environment variables (like `PICKLE_REPORT=1`) to the test runner process. Use one of these approaches instead:

1. **Subclass override** (most reliable): override `reportEnabled` / `reportOutputPath` in `TodoUITests.swift`
2. **Scheme env vars**: `project.yml` includes `PICKLE_REPORT` and `PICKLE_REPORT_PATH` variables. Set `isEnabled: true`/`false` in `project.yml` and re-run `xcodegen generate`, or toggle in Xcode's scheme editor

**Sandbox limitation:** UI test runners (`.xctrunner`) are sandboxed and cannot write to arbitrary paths. `PICKLE_REPORT_PATH` is ineffective in this context — the OS blocks all user-specified paths. PickleKit falls back to `NSTemporaryDirectory()` (the sandbox's temp dir). The actual output path is printed to stderr.

**TodoApp sandbox report path:**
```
~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html
```

```bash
# Open the report after running tests
open ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/Data/tmp/pickle-report.html

# Full sandbox cleanup
rm -rf ~/Library/Containers/com.picklekit.example.todoapp.uitests.xctrunner/
```

**Report writing mechanism:** Reports are written from both `class func tearDown()` (after each `GherkinTestCase` subclass finishes) and an `atexit` handler. The `class func tearDown()` ensures reports are generated even when `xcodebuild` terminates the test runner before `atexit` fires.

### Key Patterns

- **`nonisolated(unsafe) static var app: XCUIApplication!`** — XCUIApplication isn't Sendable, but StepHandler requires @Sendable closures. Safe because XCUITest runs sequentially.
- **App reuse across scenarios** — `setUp()` launches only once (`app == nil`), then reuses via `activate()`. Each scenario starts with a clean state via the "the todo list is empty" background step (clicks "Clear All").
- **Index-based accessibility identifiers** (`todoText_0`, `deleteButton_1`, `editButton_0`, `editTextField_0`) — deterministic IDs for ForEach with enumerated array.
- **`waitForExistence(timeout: 5)`** — all element queries use this to avoid flakiness.
- **Local package dependency** — `project.yml` references PickleKit via `path: ../..`.
- **Tag filtering** — `tagFilter` override excludes `@wip`; `CUCUMBER_TAGS` env var for CLI filtering.

## Concurrency Notes

- All AST types are `Sendable` value types
- `StepHandler` is `@Sendable ... async throws` — handlers run in async context
- `StepRegistry` is `@unchecked Sendable` — not thread-safe for concurrent registration, but safe for concurrent matching after setup
- `ScenarioRunner` is `Sendable` — safe to use from any context
- `GherkinTestCase` runs scenarios with `Task` + `waitForExpectations` to bridge XCTest's sync test methods with async step handlers
- Test warnings about `SendableClosureCaptures` in test files are expected (test-only mutable state in closures)
