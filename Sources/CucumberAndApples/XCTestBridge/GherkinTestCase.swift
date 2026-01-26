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

    // MARK: - Dynamic Test Suite

    /// Parsed and expanded scenarios mapped by sanitized method name.
    private static var scenarioMap: [String: (scenario: Scenario, background: Background?, feature: Feature)] = [:]

    override open class var defaultTestSuite: XCTestSuite {
        let suite = XCTestSuite(forTestCaseClass: self)

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
            parseError = error
            return errorSuite
        }

        let filter = tagFilter
        scenarioMap = [:]

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

                scenarioMap[selectorName] = (scenario, expanded.background, feature)

                // Create a dynamic test method
                let sel = NSSelectorFromString(selectorName)
                let block: @convention(block) (GherkinTestCase) -> Void = { testCase in
                    testCase.executeScenario(named: selectorName)
                }
                let imp = imp_implementationWithBlock(block)
                // "v@:" means void return, object self, selector _cmd
                class_addMethod(self, sel, imp, "v@:")

                if let testCase = makeTestCase(for: self, selector: sel) {
                    suite.addTest(testCase)
                }
            }
        }

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

    private static var parseError: Error?

    @objc private func reportParseError() {
        XCTFail("Failed to parse feature files: \(Self.parseError?.localizedDescription ?? "unknown error")")
    }

    // MARK: - Scenario Execution

    private func executeScenario(named selectorName: String) {
        guard let entry = Self.scenarioMap[selectorName] else {
            XCTFail("No scenario found for \(selectorName)")
            return
        }

        let (scenario, background, feature) = entry

        // Register step definitions
        registry.reset()
        registerStepDefinitions()

        let runner = ScenarioRunner(registry: registry)

        // Use XCTest async support
        let expectation = self.expectation(description: "Scenario: \(scenario.name)")

        Task {
            let result = try await runner.run(
                scenario: scenario,
                background: background,
                feature: feature
            )

            if !result.passed, let error = result.error {
                // Extract source location info for better diagnostics
                let message = self.formatError(error, scenario: scenario, feature: feature)
                XCTFail(message)
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
