# HTML Report Configuration

PickleKit generates Cucumber-style HTML reports with per-step results, timing, and status filtering. This document covers configuration options, xcodebuild integration, and programmatic report generation.

## Configuration

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

## Reports with xcodebuild

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

## Programmatic Report Generation

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
