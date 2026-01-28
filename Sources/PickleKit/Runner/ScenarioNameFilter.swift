import Foundation

/// Filters scenarios by name using case-insensitive exact matching.
///
/// Reads the `CUCUMBER_SCENARIOS` environment variable (comma-separated scenario names)
/// for runtime control. Can also be set at compile time via `GherkinTestCase.scenarioNameFilter`
/// or `GherkinTestScenario.scenarios(scenarioNameFilter:)`.
///
/// Combined with xcodebuild's `TEST_RUNNER_` prefix mechanism, this enables individual
/// scenario targeting from the CLI:
/// ```
/// TEST_RUNNER_CUCUMBER_SCENARIOS="My scenario name" \
///   xcodebuild test -project Foo.xcodeproj -scheme Foo \
///   -destination 'platform=macOS' -only-testing:MyUITests
/// ```
public struct ScenarioNameFilter: Sendable, Equatable {

    /// Lowercased scenario names for case-insensitive matching.
    public let includeNames: Set<String>

    public init(names: Set<String>) {
        self.includeNames = Set(names.map { $0.lowercased() })
    }

    /// Creates a `ScenarioNameFilter` from the `CUCUMBER_SCENARIOS` environment variable.
    /// Returns `nil` if the variable is unset or empty.
    ///
    /// Values are comma-separated and whitespace-trimmed:
    /// ```
    /// CUCUMBER_SCENARIOS="Adding two numbers,Subtracting" swift test
    /// ```
    public static func fromEnvironment() -> ScenarioNameFilter? {
        guard let raw = ProcessInfo.processInfo.environment["CUCUMBER_SCENARIOS"] else {
            return nil
        }
        let names = raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        return ScenarioNameFilter(names: Set(names))
    }

    /// Returns a new filter that unions the name sets from both filters.
    public func merging(_ other: ScenarioNameFilter) -> ScenarioNameFilter {
        ScenarioNameFilter(names: includeNames.union(other.includeNames))
    }

    /// Determine whether a scenario with the given name should be included.
    /// Matching is case-insensitive.
    public func shouldInclude(name: String) -> Bool {
        includeNames.contains(name.lowercased())
    }
}
