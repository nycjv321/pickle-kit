import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import PickleKit

/// Tests for `GherkinTestScenario` — the Swift Testing bridge that loads Gherkin features
/// and executes them as parameterized test arguments.
///
/// Uses `@Suite(.serialized)` because step definition types use `nonisolated(unsafe)
/// static var` state that is reset per-scenario via `init()`.
///
/// Count-sensitive tests use a private `loadScenarios` helper that bypasses
/// `TagFilter.fromEnvironment()` to avoid cross-suite interference from
/// `TagFilterTests` (which sets `CUCUMBER_TAGS` / `CUCUMBER_EXCLUDE_TAGS` and
/// may run concurrently). The `GherkinTestScenario.scenarios()` API merges env
/// vars into the tag filter, making it unreliable for deterministic assertions
/// when env-var-mutating tests run in parallel.
@Suite(.serialized)
struct GherkinTestScenarioTests {

    // MARK: - Helpers

    /// Load scenarios from a bundle without reading `TagFilter.fromEnvironment()`.
    /// This avoids the race condition with `TagFilterTests` setting env vars.
    private func loadScenarios(
        bundle: Bundle,
        subdirectory: String?,
        tagFilter: TagFilter? = nil
    ) throws -> [GherkinTestScenario] {
        let parser = GherkinParser()
        let features = try parser.parseBundle(bundle: bundle, subdirectory: subdirectory)
        return buildScenarios(from: features, tagFilter: tagFilter)
    }

    /// Load scenarios from filesystem paths without reading `TagFilter.fromEnvironment()`.
    private func loadScenarios(
        paths: [String],
        tagFilter: TagFilter? = nil
    ) throws -> [GherkinTestScenario] {
        let parser = GherkinParser()
        let featurePaths = paths.compactMap { FeaturePath.parse($0) }
        let result = try parser.parsePaths(featurePaths)
        return buildScenarios(from: result.features, tagFilter: tagFilter)
    }

    /// Expand features into scenarios, applying tag filter without env var merge.
    private func buildScenarios(
        from features: [Feature],
        tagFilter: TagFilter?
    ) -> [GherkinTestScenario] {
        let expander = OutlineExpander()
        var results: [GherkinTestScenario] = []
        for feature in features {
            let expanded = expander.expand(feature)
            for definition in expanded.scenarios {
                guard case .scenario(let scenario) = definition else { continue }
                if let filter = tagFilter {
                    let allTags = feature.tags + scenario.tags
                    if !filter.shouldInclude(tags: allTags) { continue }
                }
                results.append(GherkinTestScenario(
                    scenario: scenario,
                    background: expanded.background,
                    feature: feature
                ))
            }
        }
        return results
    }

    /// Load a fixture file URL by name.
    private func fixtureURL(_ name: String) throws -> URL {
        try #require(Bundle.module.url(
            forResource: name,
            withExtension: "feature",
            subdirectory: "Fixtures"
        ))
    }

    // MARK: - Loading from Bundle

    @Test func loadingScenariosFromBundle() throws {
        let scenarios = try loadScenarios(bundle: Bundle.module, subdirectory: "Fixtures")
        #expect(scenarios.count == 13)
    }

    @Test func tagFilterExcludesScenarios() throws {
        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(excludeTags: ["wip"])
        )
        #expect(scenarios.count == 12)
        let names = scenarios.map(\.scenario.name)
        #expect(!names.contains("Work in progress"))
    }

    @Test func tagFilterIncludesOnlyMatching() throws {
        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        #expect(scenarios.count == 1)
        #expect(scenarios[0].scenario.name == "Quick check")
    }

    @Test func invalidBundleSubdirectoryReturnsEmpty() {
        let scenarios = GherkinTestScenario.scenarios(
            bundle: Bundle.module,
            subdirectory: "NonexistentSubdirectory"
        )
        #expect(scenarios.isEmpty)
    }

    // MARK: - Loading from Filesystem Paths

    @Test func loadingFromFilesystemPaths() throws {
        let url = try fixtureURL("basic")
        let scenarios = try loadScenarios(paths: [url.path])
        #expect(scenarios.count == 2)
    }

    @Test func lineSpecificationLoadsFile() throws {
        let url = try fixtureURL("basic")
        // Line filtering is only applied by GherkinTestCase (XCTest bridge).
        // GherkinTestScenario loads the file but does not filter by line.
        let scenarios = try loadScenarios(paths: ["\(url.path):6"])
        #expect(scenarios.count == 2)
    }

    @Test func pathsWithTagFilter() throws {
        let url = try fixtureURL("with_tags")
        let scenarios = try loadScenarios(
            paths: [url.path],
            tagFilter: TagFilter(excludeTags: ["wip"])
        )
        #expect(scenarios.count == 2)
        let names = scenarios.map(\.scenario.name)
        #expect(!names.contains("Work in progress"))
    }

    // MARK: - Execution

    @Test func runReturnsPassingResult() async throws {
        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)
        #expect(test.scenario.name == "Quick check")

        let result = try await test.run(stepDefinitions: [TaggedSteps.self])
        #expect(result.passed)
        #expect(result.stepsExecuted == 2)
        #expect(result.stepResults.count == 2)
    }

    @Test func runWithUndefinedStepFails() async throws {
        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)

        // Run with no step definitions — all steps are undefined
        let result = try await test.run(stepDefinitions: [])
        #expect(!result.passed)
        #expect(result.error != nil)
    }

    @Test func reportCollectorRecordsResult() async throws {
        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)

        let collector = ReportResultCollector()
        try await test.run(stepDefinitions: [TaggedSteps.self], reportCollector: collector)

        let testRun = collector.buildTestRunResult()
        #expect(testRun.featureResults.count == 1)
        #expect(testRun.featureResults[0].featureName == "Tagged scenarios")
        #expect(testRun.featureResults[0].scenarioResults.count == 1)
        #expect(testRun.featureResults[0].scenarioResults[0].scenarioName == "Quick check")
    }

    // MARK: - Properties

    @Test func descriptionReturnsScenarioName() throws {
        let scenarios = try loadScenarios(bundle: Bundle.module, subdirectory: "Fixtures")
        for test in scenarios {
            #expect(test.description == test.scenario.name)
        }
    }

    @Test func backgroundIncluded() throws {
        let url = try fixtureURL("with_background")
        let scenarios = try loadScenarios(paths: [url.path])
        #expect(scenarios.count == 2)
        for test in scenarios {
            let bg = try #require(test.background)
            #expect(bg.steps.count == 2)
        }
    }

    @Test func noBackgroundWhenAbsent() throws {
        let url = try fixtureURL("basic")
        let scenarios = try loadScenarios(paths: [url.path])
        for test in scenarios {
            #expect(test.background == nil)
        }
    }

    @Test func featureTagsPreserved() throws {
        let url = try fixtureURL("with_tags")
        let scenarios = try loadScenarios(paths: [url.path])
        for test in scenarios {
            #expect(test.feature.tags.contains("smoke"))
        }
    }

    @Test func outlineExpansionProducesConcrete() throws {
        let url = try fixtureURL("with_outline")
        let scenarios = try loadScenarios(paths: [url.path])
        #expect(scenarios.count == 3)
        for test in scenarios {
            #expect(test.scenario.steps.count == 3)
        }
    }

    // MARK: - Automatic Report Collection (PICKLE_REPORT)

    @Test func autoCollectsWhenPickleReportSet() async throws {
        GherkinTestScenario.resultCollector.reset()
        unsetenv("PICKLE_REPORT")
        defer {
            unsetenv("PICKLE_REPORT")
            GherkinTestScenario.resultCollector.reset()
        }

        setenv("PICKLE_REPORT", "1", 1)

        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)

        // Run without explicit collector — should auto-collect
        try await test.run(stepDefinitions: [TaggedSteps.self])

        let testRun = GherkinTestScenario.resultCollector.buildTestRunResult()
        #expect(testRun.featureResults.count == 1)
        #expect(testRun.featureResults[0].scenarioResults.count == 1)
        #expect(testRun.featureResults[0].scenarioResults[0].scenarioName == "Quick check")
    }

    @Test func noAutoCollectWhenPickleReportUnset() async throws {
        GherkinTestScenario.resultCollector.reset()
        unsetenv("PICKLE_REPORT")
        defer {
            unsetenv("PICKLE_REPORT")
            GherkinTestScenario.resultCollector.reset()
        }

        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)

        // Run without PICKLE_REPORT — shared collector should remain empty
        try await test.run(stepDefinitions: [TaggedSteps.self])

        let testRun = GherkinTestScenario.resultCollector.buildTestRunResult()
        #expect(testRun.featureResults.isEmpty)
    }

    @Test func explicitCollectorTakesPrecedenceOverAutoReport() async throws {
        GherkinTestScenario.resultCollector.reset()
        unsetenv("PICKLE_REPORT")
        defer {
            unsetenv("PICKLE_REPORT")
            GherkinTestScenario.resultCollector.reset()
        }

        setenv("PICKLE_REPORT", "1", 1)

        let scenarios = try loadScenarios(
            bundle: Bundle.module,
            subdirectory: "Fixtures",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        let test = try #require(scenarios.first)

        // Run with explicit collector — shared collector should NOT receive the result
        let explicitCollector = ReportResultCollector()
        try await test.run(stepDefinitions: [TaggedSteps.self], reportCollector: explicitCollector)

        let explicitRun = explicitCollector.buildTestRunResult()
        #expect(explicitRun.featureResults.count == 1)

        let sharedRun = GherkinTestScenario.resultCollector.buildTestRunResult()
        #expect(sharedRun.featureResults.isEmpty)
    }

    @Test func reportEnabledReadsEnvironment() {
        unsetenv("PICKLE_REPORT")
        defer { unsetenv("PICKLE_REPORT") }

        #expect(!GherkinTestScenario.reportEnabled)

        setenv("PICKLE_REPORT", "1", 1)
        #expect(GherkinTestScenario.reportEnabled)
    }

    @Test func reportOutputPathReadsEnvironment() {
        unsetenv("PICKLE_REPORT_PATH")
        defer { unsetenv("PICKLE_REPORT_PATH") }

        #expect(GherkinTestScenario.reportOutputPath == "pickle-report.html")

        setenv("PICKLE_REPORT_PATH", "custom/report.html", 1)
        #expect(GherkinTestScenario.reportOutputPath == "custom/report.html")
    }
}
