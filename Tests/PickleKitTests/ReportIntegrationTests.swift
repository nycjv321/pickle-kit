import Testing
import Foundation
import PickleKit

/// Error type for step handler assertion failures in integration tests.
private struct IntegrationStepError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// End-to-end reporting tests that exercise the full chain:
/// `ScenarioRunner` -> `ReportResultCollector` -> `HTMLReportGenerator`.
///
/// These tests verify that thrown errors, undefined steps, and mixed pass/fail
/// scenarios are correctly captured and rendered in the HTML report.
@Suite(.serialized)
struct ReportIntegrationTests {

    // MARK: - Thrown Error Flows Through to Report

    @Test func thrownErrorProducesFailedReport() async throws {
        let registry = StepRegistry()
        registry.given("a working step") { _ in }
        registry.when("a step that fails") { _ in
            throw IntegrationStepError(message: "Something went wrong")
        }
        registry.then("this is never reached") { _ in }

        let scenario = Scenario(
            name: "Thrown error scenario",
            steps: [
                Step(keyword: .given, text: "a working step", sourceLine: 2),
                Step(keyword: .when, text: "a step that fails", sourceLine: 3),
                Step(keyword: .then, text: "this is never reached", sourceLine: 4),
            ]
        )
        let feature = Feature(name: "Error Feature", sourceFile: "error.feature")

        let runner = ScenarioRunner(registry: registry)
        let result = try await runner.run(scenario: scenario, feature: feature)

        // Verify runner result
        #expect(!result.passed)
        #expect(result.error != nil)
        #expect(result.stepResults.count == 3)
        #expect(result.stepResults[0].status == .passed)
        #expect(result.stepResults[1].status == .failed)
        #expect(result.stepResults[2].status == .skipped)

        // Record into collector and generate HTML
        let collector = ReportResultCollector()
        collector.record(
            scenarioResult: result,
            featureName: feature.name,
            featureTags: feature.tags,
            sourceFile: feature.sourceFile
        )

        let testRun = collector.buildTestRunResult()
        #expect(testRun.totalScenarioCount == 1)
        #expect(testRun.failedScenarioCount == 1)
        #expect(testRun.passedStepCount == 1)
        #expect(testRun.failedStepCount == 1)
        #expect(testRun.skippedStepCount == 1)

        let generator = HTMLReportGenerator()
        let html = generator.generate(from: testRun)

        // Verify HTML contains failure indicators
        #expect(html.contains("status-failed"))
        #expect(html.contains("step-error"))
        #expect(html.contains("Something went wrong"))
        #expect(html.contains("Thrown error scenario"))
        #expect(html.contains("Error Feature"))
    }

    // MARK: - Undefined Step Flows Through to Report

    @Test func undefinedStepProducesUndefinedReport() async throws {
        let registry = StepRegistry()
        // No steps registered — all are undefined

        let scenario = Scenario(
            name: "Undefined step scenario",
            steps: [
                Step(keyword: .given, text: "an unregistered step", sourceLine: 2),
                Step(keyword: .then, text: "also never reached", sourceLine: 3),
            ]
        )
        let feature = Feature(name: "Undefined Feature", sourceFile: "undefined.feature")

        let runner = ScenarioRunner(registry: registry)
        let result = try await runner.run(scenario: scenario, feature: feature)

        #expect(!result.passed)
        #expect(result.stepResults.count == 2)
        #expect(result.stepResults[0].status == .undefined)
        #expect(result.stepResults[1].status == .skipped)

        // Record and generate HTML
        let collector = ReportResultCollector()
        collector.record(
            scenarioResult: result,
            featureName: feature.name,
            featureTags: feature.tags,
            sourceFile: feature.sourceFile
        )

        let testRun = collector.buildTestRunResult()
        #expect(testRun.undefinedStepCount == 1)
        #expect(testRun.skippedStepCount == 1)

        let generator = HTMLReportGenerator()
        let html = generator.generate(from: testRun)

        #expect(html.contains("undefined"))
        #expect(html.contains("an unregistered step"))
        #expect(html.contains("Undefined step scenario"))
    }

    // MARK: - Mixed Pass/Fail Scenario Counts

    @Test func mixedPassFailScenarioCountsInReport() async throws {
        let registry = StepRegistry()
        registry.given("step A") { _ in }
        registry.when("step B") { _ in }
        registry.then("step C passes") { _ in }
        registry.then("step C fails") { _ in
            throw IntegrationStepError(message: "Assertion failed")
        }

        let passingScenario = Scenario(
            name: "Passing scenario",
            steps: [
                Step(keyword: .given, text: "step A", sourceLine: 2),
                Step(keyword: .when, text: "step B", sourceLine: 3),
                Step(keyword: .then, text: "step C passes", sourceLine: 4),
            ]
        )

        let failingScenario = Scenario(
            name: "Failing scenario",
            steps: [
                Step(keyword: .given, text: "step A", sourceLine: 7),
                Step(keyword: .when, text: "step B", sourceLine: 8),
                Step(keyword: .then, text: "step C fails", sourceLine: 9),
            ]
        )

        let feature = Feature(name: "Mixed Feature", sourceFile: "mixed.feature")
        let runner = ScenarioRunner(registry: registry)

        let passResult = try await runner.run(scenario: passingScenario, feature: feature)
        let failResult = try await runner.run(scenario: failingScenario, feature: feature)

        #expect(passResult.passed)
        #expect(!failResult.passed)

        let collector = ReportResultCollector()
        collector.record(
            scenarioResult: passResult,
            featureName: feature.name,
            featureTags: feature.tags,
            sourceFile: feature.sourceFile
        )
        collector.record(
            scenarioResult: failResult,
            featureName: feature.name,
            featureTags: feature.tags,
            sourceFile: feature.sourceFile
        )

        let testRun = collector.buildTestRunResult()
        #expect(testRun.totalFeatureCount == 1)
        #expect(testRun.failedFeatureCount == 1) // Feature has at least one failure
        #expect(testRun.totalScenarioCount == 2)
        #expect(testRun.passedScenarioCount == 1)
        #expect(testRun.failedScenarioCount == 1)
        #expect(testRun.totalStepCount == 6) // 3 passed + 2 passed + 1 failed
        #expect(testRun.passedStepCount == 5)
        #expect(testRun.failedStepCount == 1)

        let generator = HTMLReportGenerator()
        let html = generator.generate(from: testRun)

        // Verify both passing and failing scenarios appear
        #expect(html.contains("Passing scenario"))
        #expect(html.contains("Failing scenario"))
        #expect(html.contains("status-passed"))
        #expect(html.contains("status-failed"))
        // Verify summary counts are rendered
        #expect(html.contains("1 passed, 1 failed"))
    }

    // MARK: - Tag Filtering in Reports

    @Test func excludedTagScenariosAbsentFromReport() async throws {
        // Uses synthetic scenarios with inline step handlers to avoid racing
        // with GherkinIntegrationTests for shared StepDefinitions static state.
        let parser = GherkinParser()
        let features = try parser.parseBundle(bundle: Bundle.module, subdirectory: "Fixtures")
        let expander = OutlineExpander()
        let filter = TagFilter(excludeTags: ["wip"])
        let collector = ReportResultCollector()

        for feature in features {
            let expanded = expander.expand(feature)
            for definition in expanded.scenarios {
                guard case .scenario(let scenario) = definition else { continue }
                let allTags = feature.tags + scenario.tags
                guard filter.shouldInclude(tags: allTags) else { continue }

                // Register a catch-all handler so every step passes without
                // touching the shared static state in domain StepDefinitions types.
                let registry = StepRegistry()
                for step in (expanded.background?.steps ?? []) + scenario.steps {
                    registry.step(NSRegularExpression.escapedPattern(for: step.text)) { _ in }
                }
                let runner = ScenarioRunner(registry: registry)
                let result = try await runner.run(
                    scenario: scenario, background: expanded.background, feature: feature
                )
                collector.record(
                    scenarioResult: result,
                    featureName: feature.name,
                    featureTags: feature.tags,
                    sourceFile: feature.sourceFile
                )
            }
        }

        let testRun = collector.buildTestRunResult()
        let html = HTMLReportGenerator().generate(from: testRun)

        // @wip scenario must be absent
        #expect(!html.contains("Work in progress"))

        // Non-excluded scenarios from with_tags.feature must be present
        #expect(html.contains("Quick check"))
        #expect(html.contains("Full integration"))
    }

    @Test func includeTagFilterLimitsReportToMatchingScenarios() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "with_tags", withExtension: "feature", subdirectory: "Fixtures")
        )
        let source = try String(contentsOf: url, encoding: .utf8)
        let parser = GherkinParser()
        let feature = try parser.parse(source: source, fileName: "with_tags.feature")
        let expanded = OutlineExpander().expand(feature)
        let filter = TagFilter(includeTags: ["fast"])
        let collector = ReportResultCollector()

        for definition in expanded.scenarios {
            guard case .scenario(let scenario) = definition else { continue }
            let allTags = feature.tags + scenario.tags
            guard filter.shouldInclude(tags: allTags) else { continue }

            let registry = StepRegistry()
            for step in (expanded.background?.steps ?? []) + scenario.steps {
                registry.step(NSRegularExpression.escapedPattern(for: step.text)) { _ in }
            }
            let runner = ScenarioRunner(registry: registry)
            let result = try await runner.run(
                scenario: scenario, background: expanded.background, feature: feature
            )
            collector.record(
                scenarioResult: result,
                featureName: feature.name,
                featureTags: feature.tags,
                sourceFile: feature.sourceFile
            )
        }

        let testRun = collector.buildTestRunResult()
        let html = HTMLReportGenerator().generate(from: testRun)

        // Only the @fast scenario should appear
        #expect(html.contains("Quick check"))
        #expect(!html.contains("Full integration"))
        #expect(!html.contains("Work in progress"))

        // Exactly 1 scenario in the report
        #expect(testRun.totalScenarioCount == 1)
        #expect(testRun.passedScenarioCount == 1)
    }

    @Test func featureAndScenarioTagsRenderedInReport() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "with_tags", withExtension: "feature", subdirectory: "Fixtures")
        )
        let source = try String(contentsOf: url, encoding: .utf8)
        let parser = GherkinParser()
        let feature = try parser.parse(source: source, fileName: "with_tags.feature")
        let expanded = OutlineExpander().expand(feature)
        let collector = ReportResultCollector()

        for definition in expanded.scenarios {
            guard case .scenario(let scenario) = definition else { continue }

            let registry = StepRegistry()
            for step in (expanded.background?.steps ?? []) + scenario.steps {
                registry.step(NSRegularExpression.escapedPattern(for: step.text)) { _ in }
            }
            let runner = ScenarioRunner(registry: registry)
            let result = try await runner.run(
                scenario: scenario, background: expanded.background, feature: feature
            )
            collector.record(
                scenarioResult: result,
                featureName: feature.name,
                featureTags: feature.tags,
                sourceFile: feature.sourceFile
            )
        }

        let testRun = collector.buildTestRunResult()
        let html = HTMLReportGenerator().generate(from: testRun)

        // Feature-level tag rendered
        #expect(html.contains("@smoke"))

        // Scenario-level tags rendered
        #expect(html.contains("@fast"))
        #expect(html.contains("@slow"))
        #expect(html.contains("@integration"))
        #expect(html.contains("@wip"))

        // All 3 scenarios present (no filter applied)
        #expect(testRun.totalScenarioCount == 3)
    }

    // MARK: - Report File Write Round-Trip

    @Test func reportWritesToFile() async throws {
        let registry = StepRegistry()
        registry.given("a simple step") { _ in }

        let scenario = Scenario(
            name: "File write scenario",
            steps: [
                Step(keyword: .given, text: "a simple step", sourceLine: 2),
            ]
        )
        let feature = Feature(name: "File Write Feature")

        let runner = ScenarioRunner(registry: registry)
        let result = try await runner.run(scenario: scenario, feature: feature)

        let collector = ReportResultCollector()
        collector.record(
            scenarioResult: result,
            featureName: feature.name,
            featureTags: feature.tags,
            sourceFile: feature.sourceFile
        )

        let testRun = collector.buildTestRunResult()
        let generator = HTMLReportGenerator()

        let tempDir = NSTemporaryDirectory()
        let reportPath = (tempDir as NSString).appendingPathComponent("pickle-integration-test-report.html")
        defer { try? FileManager.default.removeItem(atPath: reportPath) }

        try generator.write(result: testRun, to: reportPath)

        let reportContent = try String(contentsOfFile: reportPath, encoding: .utf8)
        #expect(reportContent.contains("PickleKit Test Report"))
        #expect(reportContent.contains("File Write Feature"))
        #expect(reportContent.contains("File write scenario"))
    }
}
