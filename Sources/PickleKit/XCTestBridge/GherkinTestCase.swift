#if canImport(XCTest) && canImport(ObjectiveC)
import XCTest
import ObjectiveC
import Foundation

/// Base class for Gherkin-driven XCTest suites.
///
/// Subclass this in your test target and override `registerStepDefinitions()`
/// and `featureBundle` / `featureSubdirectory` to configure which feature files
/// are loaded and how steps are matched.
///
/// Each scenario becomes a separate test method in the Xcode test navigator.
///
/// Example:
/// ```swift
/// final class MyFeatureTests: GherkinTestCase {
///     override class var featureSubdirectory: String? { "Features" }
///
///     override func registerStepDefinitions() {
///         given("I have (\\d+) apples") { match in
///             let count = Int(match.captures[0])!
///             // ...
///         }
///     }
/// }
/// ```
open class GherkinTestCase: XCTestCase {

    // MARK: - Configuration (Override in Subclasses)

    /// The bundle containing .feature files. Defaults to the test bundle.
    open class var featureBundle: Bundle { Bundle(for: self) }

    /// Subdirectory within the bundle to search for .feature files.
    open class var featureSubdirectory: String? { nil }

    /// Optional tag filter. Override to include/exclude scenarios by tags.
    open class var tagFilter: TagFilter? { nil }

    /// Whether HTML report generation is enabled. Reads `PICKLE_REPORT` env var.
    /// Override in subclass for compile-time control.
    open class var reportEnabled: Bool {
        ProcessInfo.processInfo.environment["PICKLE_REPORT"] != nil
    }

    /// Output path for the HTML report. Reads `PICKLE_REPORT_PATH` env var.
    /// Override in subclass for compile-time control.
    open class var reportOutputPath: String {
        ProcessInfo.processInfo.environment["PICKLE_REPORT_PATH"] ?? "pickle-report.html"
    }

    /// Override to register step definitions before scenarios run.
    open func registerStepDefinitions() {
        // Subclasses override this
    }

    // MARK: - Registry Access

    /// The step registry for this test case instance.
    public let registry = StepRegistry()

    /// Convenience: register a Given step.
    public func given(_ pattern: String, handler: @escaping StepHandler) {
        registry.given(pattern, handler: handler)
    }

    /// Convenience: register a When step.
    public func when(_ pattern: String, handler: @escaping StepHandler) {
        registry.when(pattern, handler: handler)
    }

    /// Convenience: register a Then step.
    public func then(_ pattern: String, handler: @escaping StepHandler) {
        registry.then(pattern, handler: handler)
    }

    /// Convenience: register a step (keyword-agnostic).
    public func step(_ pattern: String, handler: @escaping StepHandler) {
        registry.step(pattern, handler: handler)
    }

    // MARK: - Report Collection

    /// Shared result collector for HTML report generation across all GherkinTestCase subclasses.
    nonisolated(unsafe) private static var _resultCollector = ReportResultCollector()
    nonisolated(unsafe) private static var _atexitRegistered = false

    /// The shared result collector. Accessible for programmatic use.
    public static var resultCollector: ReportResultCollector { _resultCollector }

    /// Write the collected report to disk. Called from both `atexit` (for `swift test`)
    /// and `class func tearDown()` (for `xcodebuild` where the process may be killed
    /// before `atexit` handlers fire).
    private static func writeReportIfNeeded() {
        let result = _resultCollector.buildTestRunResult()
        guard !result.featureResults.isEmpty else { return }
        let rawPath = ProcessInfo.processInfo.environment["PICKLE_REPORT_PATH"] ?? "pickle-report.html"
        // Resolve to absolute path so the output location is unambiguous,
        // especially under xcodebuild where the working directory may differ.
        let absolutePath: String
        if rawPath.hasPrefix("/") {
            absolutePath = rawPath
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            absolutePath = (cwd as NSString).appendingPathComponent(rawPath)
        }
        let generator = HTMLReportGenerator()
        do {
            try generator.write(result: result, to: absolutePath)
            fputs("PickleKit: HTML report written to \(absolutePath)\n", stderr)
        } catch {
            // Fall back to the sandbox-writable temp directory (common when
            // running UI tests via xcodebuild, where the runner is sandboxed).
            let fallbackPath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent((rawPath as NSString).lastPathComponent)
            do {
                try generator.write(result: result, to: fallbackPath)
                fputs("PickleKit: HTML report written to \(fallbackPath)\n", stderr)
            } catch {
                fputs("PickleKit: Failed to write report: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private static func ensureAtexitRegistered() {
        guard !_atexitRegistered else { return }
        _atexitRegistered = true
        atexit {
            GherkinTestCase.writeReportIfNeeded()
        }
    }

    /// Write an incremental report after each test class finishes.
    /// This ensures reports are generated even when the test runner process
    /// is terminated (e.g., by xcodebuild) before `atexit` handlers fire.
    override open class func tearDown() {
        if _atexitRegistered {
            writeReportIfNeeded()
        }
        super.tearDown()
    }

    // MARK: - Dynamic Test Suite

    /// Parsed and expanded scenarios mapped by sanitized method name, keyed per class.
    /// Each GherkinTestCase subclass gets its own scenario map so that multiple
    /// subclasses (or the base class itself) don't overwrite each other's data.
    private static var scenarioMaps: [ObjectIdentifier: [String: (scenario: Scenario, background: Background?, feature: Feature)]] = [:]

    override open class var defaultTestSuite: XCTestSuite {
        let classId = ObjectIdentifier(self)

        // Parse features
        let parser = GherkinParser()
        let expander = OutlineExpander()

        let features: [Feature]
        do {
            features = try parser.parseBundle(bundle: featureBundle, subdirectory: featureSubdirectory)
        } catch {
            // Create a single failing test to report the parse error
            let errorSuite = XCTestSuite(name: String(describing: self))
            let sel = #selector(reportParseError)
            if let testCase = makeTestCase(for: self, selector: sel) {
                errorSuite.addTest(testCase)
            }
            parseErrors[classId] = error
            return errorSuite
        }

        let envFilter = TagFilter.fromEnvironment()
        let filter: TagFilter?
        switch (tagFilter, envFilter) {
        case let (compileTime?, env?):
            filter = compileTime.merging(env)
        case let (compileTime?, nil):
            filter = compileTime
        case let (nil, env?):
            filter = env
        case (nil, nil):
            filter = nil
        }
        scenarioMaps[classId] = [:]

        for feature in features {
            let expanded = expander.expand(feature)

            for definition in expanded.scenarios {
                guard case .scenario(let scenario) = definition else { continue }

                // Apply tag filter
                if let filter = filter {
                    let allTags = feature.tags + scenario.tags
                    if !filter.shouldInclude(tags: allTags) {
                        continue
                    }
                }

                let methodName = sanitizeMethodName(scenario.name)
                let selectorName = "test_\(methodName)"

                scenarioMaps[classId]?[selectorName] = (scenario, expanded.background, feature)

                // Add dynamic test method to the class. class_addMethod is a no-op
                // if the selector already exists, so repeated calls are safe.
                let sel = NSSelectorFromString(selectorName)
                let block: @convention(block) (GherkinTestCase) -> Void = { testCase in
                    testCase.executeScenario(named: selectorName)
                }
                let imp = imp_implementationWithBlock(block)
                // "v@:" means void return, object self, selector _cmd
                class_addMethod(self, sel, imp, "v@:")
            }
        }

        // Create suite AFTER all dynamic methods are added to the class.
        // XCTestSuite(forTestCaseClass:) discovers test_* methods via ObjC
        // reflection, so it will find all dynamically added methods.
        // This avoids duplicate test entries that can crash Xcode's result
        // bundle builder when defaultTestSuite is called multiple times.
        let suite = XCTestSuite(forTestCaseClass: self)
        return suite
    }

    /// Create an XCTestCase instance via the ObjC runtime, bypassing Swift's
    /// unavailability of `init(selector:)`.
    private static func makeTestCase(for cls: AnyClass, selector: Selector) -> XCTestCase? {
        typealias Factory = @convention(c) (AnyClass, Selector, Selector) -> XCTestCase?
        let factorySel = NSSelectorFromString("testCaseWithSelector:")
        guard let method = class_getClassMethod(cls, factorySel) else { return nil }
        let imp = method_getImplementation(method)
        let factory = unsafeBitCast(imp, to: Factory.self)
        return factory(cls, factorySel, selector)
    }

    // MARK: - Error Reporting

    private static var parseErrors: [ObjectIdentifier: Error] = [:]

    @objc private func reportParseError() {
        let classId = ObjectIdentifier(type(of: self))
        let error = Self.parseErrors[classId]
        XCTFail("Failed to parse feature files: \(error?.localizedDescription ?? "unknown error")")
    }

    // MARK: - Scenario Execution

    private func executeScenario(named selectorName: String) {
        let classId = ObjectIdentifier(type(of: self))
        guard let entry = Self.scenarioMaps[classId]?[selectorName] else {
            XCTFail("No scenario found for \(selectorName)")
            return
        }

        let (scenario, background, feature) = entry
        let reportingEnabled = type(of: self).reportEnabled

        if reportingEnabled {
            Self.ensureAtexitRegistered()
        }

        // Register step definitions
        registry.reset()
        registerStepDefinitions()

        if !registry.registrationErrors.isEmpty {
            for error in registry.registrationErrors {
                XCTFail(error.localizedDescription)
            }
            return
        }

        let runner = ScenarioRunner(registry: registry)

        // Use XCTest async support
        let expectation = self.expectation(description: "Scenario: \(scenario.name)")

        Task {
            do {
                let result = try await runner.run(
                    scenario: scenario,
                    background: background,
                    feature: feature
                )

                if reportingEnabled {
                    Self._resultCollector.record(
                        scenarioResult: result,
                        featureName: feature.name,
                        featureTags: feature.tags,
                        sourceFile: feature.sourceFile
                    )
                }

                if !result.passed, let error = result.error {
                    let message = self.formatError(error, scenario: scenario, feature: feature)
                    XCTFail(message)
                }
            } catch {
                XCTFail("Scenario '\(scenario.name)' threw an unexpected error: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 60)
    }

    // MARK: - Helpers

    private func formatError(_ error: Error, scenario: Scenario, feature: Feature) -> String {
        if let runnerError = error as? ScenarioRunnerError {
            switch runnerError {
            case .undefinedStep(let step, _, _):
                return "Undefined step at \(feature.sourceFile ?? "?"):\(step.sourceLine) — "
                    + "\(step.keyword.rawValue) \(step.text)"
            case .stepFailed(let step, _, _, let underlying):
                return "Step failed at \(feature.sourceFile ?? "?"):\(step.sourceLine) — "
                    + "\(step.keyword.rawValue) \(step.text)\n"
                    + "Error: \(underlying.localizedDescription)"
            }
        }
        return "Scenario '\(scenario.name)' failed: \(error.localizedDescription)"
    }

    private static func sanitizeMethodName(_ name: String) -> String {
        // Replace non-alphanumeric characters with underscores
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return name.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
#endif
