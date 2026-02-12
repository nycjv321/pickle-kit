# BDD Conventions Guide

Conventions for writing Gherkin feature files and PickleKit step definitions in Swift projects. These patterns are reusable across any project using PickleKit with the `GherkinTestScenario` (Swift Testing) bridge.

For Gherkin syntax reference, see [GHERKIN.md](GHERKIN.md). For test design philosophy, see [TESTING.md](TESTING.md). For AI-assisted development workflows, see [AI-DEVELOPMENT.md](AI-DEVELOPMENT.md).

---

## Features

How to design and write Gherkin feature files.

### Step Design

Each step in the feature file should represent a single **business concept**. Implementation details — intermediate objects, verification mechanics, multi-step procedures — belong in the step definition, not the feature file. When a step needs to vary its behavior by context (format, configuration, input type), push that logic into the step implementation rather than splitting into multiple steps.

#### Given steps — describe *what state exists*, not *how it's constructed*

Consolidate setup plumbing (creating intermediate objects, wiring relationships) into a single step that declares the precondition at the business level.

| Approach | Feature file | Step implementation |
|----------|-------------|---------------------|
| **Prefer** | `Given album "X" by "Y" in the source` | Step creates artist, album, and song internally |
| **Avoid** | 3 separate Given steps for artist, album, and song | Each step creates one object |

**Guideline:** If a Given step exists only to set up an intermediate object that another Given step depends on, consolidate them. The feature file declares *what precondition exists*; the step definition handles the construction.

#### When steps — describe *what action the user takes*, not *the implementation steps*

Consolidate multi-step operations into a single step that captures the user intent.

| Approach | Feature file | Step implementation |
|----------|-------------|---------------------|
| **Prefer** | `When I convert the album to ALAC` | Step selects songs, configures encoding, runs conversion |
| **Avoid** | 3 separate When steps for select, configure, execute | Each step does one sub-operation |

**Guideline:** If a When step is always preceded by the same other When steps, consolidate them. The feature file describes *what the user does*; the step definition handles the procedure.

#### Then steps — describe *what the outcome is*, not *how to verify it*

Consolidate verification details into a single step that asserts the business result.

| Approach | Feature file | Step implementation |
|----------|-------------|---------------------|
| **Prefer** | `Then the metadata is updated` | Step reads context, checks the fields that apply |
| **Avoid** | 6 separate Then steps for each field | Each step checks one field |

**Guideline:** If a Then step could be named "the X is done" and the substeps are just verification details, consolidate into one step. The feature file describes *what* the outcome is; the step definition decides *how* to verify it.

**Examples across all step types:**
- `Given album "X" by "Y" in the source` — internally creates artist, album, and default song
- `When I convert the album to ALAC` — internally selects songs, configures settings, runs conversion
- `Then the cover art is set` — internally verifies art exists AND bytes match the original
- `Then the metadata is updated` — internally checks the fields the format supports

### Conventions

```gherkin
Feature: <Name>
  <1-2 sentence description of what the feature covers.>

  # --- Section comment ---

  Scenario: <Descriptive name in present tense>
    Given <precondition>
    When <action>
    Then <expected outcome>
    And <additional assertion>

  Scenario Outline: <Name with parameter>
    Given a "<param>" input
    When I <action>
    Then <assertion>

    Examples:
      | param  |
      | value1 |
      | value2 |
```

- Start with a `Feature:` block and a brief description of what the feature covers
- Group related scenarios with `# --- Section comment ---` dividers
- Use `Scenario` for unique workflows, `Scenario Outline` with `Examples` for matrix tests
- Write steps in natural language: `Given an empty list`, `When I add an item`, `Then the count is 1`
- Use quoted strings for variable values: `item "Milk" has status "active"`
- Use bare integers for numeric values: `the count is 3`, `has index 1`

### When to Use Scenario Outline

Use `Scenario Outline` when:
- The **same workflow** is exercised across **varying inputs**
- The Examples table has 3+ rows or is likely to grow
- All rows share identical Given/When/Then structure

Keep separate Scenarios when:
- When steps differ structurally between cases
- Only 2 rows exist and the table won't grow
- Different assertion logic is needed per case

---

## Steps

How to design and write step definitions and runners.

### Architecture

Each feature gets its own runner and step definitions rather than sharing across features. This is intentional:

1. **Step isolation** — Each runner registers only its own step definitions, preventing regex pattern collisions across unrelated domains.
2. **Test target boundaries** — Runners can live in separate test targets with different dependencies. A shared runner would need every dependency.
3. **Parallel execution** — `@Suite(.serialized)` serializes scenarios within a suite (required for shared `TestContext` state). Separate suites let unrelated features run in parallel. A single runner would serialize everything.

### File Organization

Each feature suite has 4-5 files:

```
Tests/<Target>/
├── Steps/
│   ├── <Feature>TestContext.swift       # Shared mutable state
│   ├── <Feature>SetupSteps.swift        # Given steps + error enum
│   ├── <Feature>ActionSteps.swift       # When steps
│   └── <Feature>VerificationSteps.swift # Then steps
└── <Feature>BDDTests.swift              # Runner
```

- **SetupSteps** — Given steps and the error enum. `init()` calls `reset()` on the TestContext.
- **ActionSteps** — When steps. `init()` is empty.
- **VerificationSteps** — Then steps. `init()` is empty.

### TestContext Pattern

```swift
/// Shared mutable state for <feature> BDD step definitions.
/// Reset per-scenario via `<Feature>SetupSteps.init()`.
///
/// Safe because BDD tests run `.serialized` and step handlers run `@MainActor`.
final class <Feature>TestContext: @unchecked Sendable {
    nonisolated(unsafe) static var shared = <Feature>TestContext()

    // Infrastructure
    var service: MyService?

    // Domain objects populated during Given/When steps
    var result: MyResult?
    // ... add fields for your domain

    func reset() {
        service = nil
        result = nil
        // ... reset all fields
    }
}
```

- `@unchecked Sendable` — safe because `@Suite(.serialized)` prevents concurrent access
- `nonisolated(unsafe) static var shared` — singleton accessed by all step definitions
- `reset()` — must nil/clear every field; called at the start of each scenario in `SetupSteps.init()`
- `static let` for fixture paths — computed once from `#filePath`

### Step Definition Conventions

```swift
/// Given steps for <feature> BDD scenarios.
struct <Feature>SetupSteps: StepDefinitions {
    init() {
        let ctx = <Feature>TestContext.shared
        ctx.reset()  // Always reset first — ensures clean state per scenario
        // Initialize infrastructure that every scenario needs
    }

    /// Given <description>
    let givenSomething = StepDefinition.given(
        #"<regex pattern>"#
    ) { match in
        let ctx = <Feature>TestContext.shared
        // Set up preconditions...
    }
}
```

- Each step is a `let` stored property with a `StepDefinition.given/when/then()` value
- Use raw string literals for regex: `#"item "([^"]+)" has status "([^"]+)""#`
- Access captures via `match.captures[0]`, `match.captures[1]`, etc.
- Step closures support `async`/`await` — call async service methods directly
- Use `guard let` with `throw <Feature>StepError.setup(...)` for missing prerequisites
- Use `#expect()` from Swift Testing for assertions in Then steps
- Only `SetupSteps.init()` calls `reset()` — other step structs use empty `init() {}`
- Comment each step with `/// Given/When/Then <step text>` for discoverability
- Extract shared query logic into `private func` helpers at file scope

### Error Enum

Each feature suite defines an error enum for step failures:

```swift
enum <Feature>StepError: Error, CustomStringConvertible {
    case setup(String)
    case assertion(String)

    var description: String {
        switch self {
        case let .setup(msg): "Setup error: \(msg)"
        case let .assertion(msg): "Assertion failed: \(msg)"
        }
    }
}
```

### Runner Conventions

```swift
@Suite(.serialized)
struct <Feature>BDDTests {
    private static let featuresPath: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // <Target>/
            // ... navigate to features directory
            .path
    }()

    static let allScenarios = GherkinTestScenario.scenarios(paths: [featuresPath])

    @Test(arguments: <Feature>BDDTests.allScenarios)
    func scenario(_ test: GherkinTestScenario) async throws {
        let result = try await test.run(stepDefinitions: [
            <Feature>SetupSteps.self,
            <Feature>ActionSteps.self,
            <Feature>VerificationSteps.self,
        ])
        #expect(result.passed, "Scenario '\(test.description)' failed: \(failureDetails(result))")
    }

    private func failureDetails(_ result: ScenarioResult) -> String {
        result.stepResults
            .filter { $0.status != .passed }
            .map { "\($0.keyword) \($0.text): \($0.error ?? "unknown error")" }
            .joined(separator: "\n")
    }
}
```

- `@Suite(.serialized)` is required — never omit it
- `featuresPath` uses `#filePath` relative navigation — count `deletingLastPathComponent()` calls based on directory depth
- `allScenarios` is a `static let` — computed once, shared across all `@Test(arguments:)` invocations
- Step definitions are passed in order: Setup, Action, Verification
- The `failureDetails` helper formats failed steps for readable test output

To adopt these conventions in your project, see [SETUP.md](SETUP.md).
