import Foundation

/// A lightweight scenario wrapper for use with Swift Testing's `@Test(arguments:)`.
///
/// `GherkinTestScenario` loads and expands Gherkin feature files into individual
/// scenario test cases, each of which can be executed against step definition types.
///
/// Usage with Swift Testing:
/// ```swift
/// import Testing
/// import PickleKit
///
/// @Suite struct MyTests {
///     @Test(arguments: GherkinTestScenario.scenarios(
///         bundle: .module, subdirectory: "Features"
///     ))
///     func scenario(_ test: GherkinTestScenario) async throws {
///         let result = try await test.run(stepDefinitions: [MySteps.self])
///         #expect(result.passed)
///     }
/// }
/// ```
public struct GherkinTestScenario: Sendable, CustomStringConvertible {

    /// The concrete scenario to execute.
    public let scenario: Scenario

    /// Optional background steps to run before the scenario.
    public let background: Background?

    /// The feature this scenario belongs to.
    public let feature: Feature

    /// Display name for Swift Testing's parameterized test labels.
    public var description: String { scenario.name }

    public init(scenario: Scenario, background: Background?, feature: Feature) {
        self.scenario = scenario
        self.background = background
        self.feature = feature
    }

    // MARK: - Loading from Bundle

    /// Load scenarios from a bundle directory, expanding outlines and applying tag filters.
    ///
    /// - Parameters:
    ///   - bundle: The bundle containing `.feature` files.
    ///   - subdirectory: Optional subdirectory within the bundle.
    ///   - tagFilter: Optional tag filter to include/exclude scenarios.
    /// - Returns: An array of test scenarios ready for `@Test(arguments:)`.
    public static func scenarios(
        bundle: Bundle,
        subdirectory: String? = nil,
        tagFilter: TagFilter? = nil
    ) -> [GherkinTestScenario] {
        let parser = GherkinParser()
        let features: [Feature]
        do {
            features = try parser.parseBundle(bundle: bundle, subdirectory: subdirectory)
        } catch {
            return []
        }
        return buildScenarios(from: features, tagFilter: tagFilter)
    }

    // MARK: - Loading from Filesystem Paths

    /// Load scenarios from filesystem paths, expanding outlines and applying tag filters.
    ///
    /// - Parameters:
    ///   - paths: Array of path specification strings (files, directories, or `file:line` syntax).
    ///   - tagFilter: Optional tag filter to include/exclude scenarios.
    /// - Returns: An array of test scenarios ready for `@Test(arguments:)`.
    public static func scenarios(
        paths: [String],
        tagFilter: TagFilter? = nil
    ) -> [GherkinTestScenario] {
        let parser = GherkinParser()
        let featurePaths = paths.compactMap { FeaturePath.parse($0) }
        let features: [Feature]
        do {
            let result = try parser.parsePaths(featurePaths)
            features = result.features
        } catch {
            return []
        }
        return buildScenarios(from: features, tagFilter: tagFilter)
    }

    // MARK: - Execution

    /// Execute this scenario against the given step definition types.
    ///
    /// - Parameters:
    ///   - stepDefinitions: Step definition types to instantiate and register.
    ///   - reportCollector: Optional collector for HTML report generation.
    /// - Returns: The scenario result.
    @discardableResult
    public func run(
        stepDefinitions: [any StepDefinitions.Type],
        reportCollector: ReportResultCollector? = nil
    ) async throws -> ScenarioResult {
        let registry = StepRegistry()

        var stepTypes = stepDefinitions
        if let envFilter = StepDefinitionFilter.fromEnvironment() {
            stepTypes = stepTypes.filter { envFilter.contains(String(describing: $0)) }
        }
        for stepType in stepTypes {
            let provider = stepType.init()
            provider.register(in: registry)
        }

        let runner = ScenarioRunner(registry: registry)
        let result = try await runner.run(
            scenario: scenario,
            background: background,
            feature: feature
        )

        if let collector = reportCollector {
            collector.record(
                scenarioResult: result,
                featureName: feature.name,
                featureTags: feature.tags,
                sourceFile: feature.sourceFile
            )
        }

        return result
    }

    // MARK: - Private

    private static func buildScenarios(
        from features: [Feature],
        tagFilter: TagFilter?
    ) -> [GherkinTestScenario] {
        let expander = OutlineExpander()
        let envFilter = TagFilter.fromEnvironment()

        let mergedFilter: TagFilter?
        switch (tagFilter, envFilter) {
        case let (compileTime?, env?):
            mergedFilter = compileTime.merging(env)
        case let (compileTime?, nil):
            mergedFilter = compileTime
        case let (nil, env?):
            mergedFilter = env
        case (nil, nil):
            mergedFilter = nil
        }

        var results: [GherkinTestScenario] = []

        for feature in features {
            let expanded = expander.expand(feature)

            for definition in expanded.scenarios {
                guard case .scenario(let scenario) = definition else { continue }

                if let filter = mergedFilter {
                    let allTags = feature.tags + scenario.tags
                    if !filter.shouldInclude(tags: allTags) {
                        continue
                    }
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
}
