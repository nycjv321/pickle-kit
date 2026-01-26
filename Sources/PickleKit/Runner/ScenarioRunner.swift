import Foundation

// MARK: - Runner Errors

public enum ScenarioRunnerError: Error, LocalizedError {
    case undefinedStep(step: Step, feature: String?, file: String?)
    case stepFailed(step: Step, feature: String?, scenario: String?, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .undefinedStep(let step, let feature, let file):
            let location = [file, feature].compactMap { $0 }.joined(separator: " / ")
            return "Undefined step at line \(step.sourceLine): \(step.keyword.rawValue) \(step.text)"
                + (location.isEmpty ? "" : " (\(location))")
        case .stepFailed(let step, _, let scenario, let error):
            return "Step failed at line \(step.sourceLine) in '\(scenario ?? "unknown")': "
                + "\(step.keyword.rawValue) \(step.text) — \(error.localizedDescription)"
        }
    }
}

// MARK: - Scenario Result

public struct ScenarioResult: Sendable {
    public let scenarioName: String
    public let passed: Bool
    public let error: (any Error)?
    public let stepsExecuted: Int

    public init(scenarioName: String, passed: Bool, error: (any Error)? = nil, stepsExecuted: Int = 0) {
        self.scenarioName = scenarioName
        self.passed = passed
        self.error = error
        self.stepsExecuted = stepsExecuted
    }
}

// MARK: - Feature Result

public struct FeatureResult: Sendable {
    public let featureName: String
    public let scenarioResults: [ScenarioResult]

    public var passedCount: Int { scenarioResults.filter(\.passed).count }
    public var failedCount: Int { scenarioResults.filter { !$0.passed }.count }
    public var allPassed: Bool { scenarioResults.allSatisfy(\.passed) }
}

// MARK: - Scenario Runner

/// Executes scenarios against a step registry.
public final class ScenarioRunner: Sendable {

    private let registry: StepRegistry

    public init(registry: StepRegistry) {
        self.registry = registry
    }

    // MARK: - Run Single Scenario

    /// Run a single scenario, optionally with background steps.
    public func run(
        scenario: Scenario,
        background: Background? = nil,
        feature: Feature? = nil
    ) async throws -> ScenarioResult {
        var stepsExecuted = 0

        do {
            // Run background steps first
            if let background = background {
                for step in background.steps {
                    try await executeStep(step, feature: feature)
                    stepsExecuted += 1
                }
            }

            // Run scenario steps
            for step in scenario.steps {
                try await executeStep(step, feature: feature)
                stepsExecuted += 1
            }

            return ScenarioResult(
                scenarioName: scenario.name,
                passed: true,
                stepsExecuted: stepsExecuted
            )
        } catch {
            return ScenarioResult(
                scenarioName: scenario.name,
                passed: false,
                error: error,
                stepsExecuted: stepsExecuted
            )
        }
    }

    // MARK: - Run Feature

    /// Run all scenarios in a feature, expanding outlines first.
    public func run(feature: Feature, tagFilter: TagFilter? = nil) async throws -> FeatureResult {
        let expander = OutlineExpander()
        let expandedFeature = expander.expand(feature)

        var results: [ScenarioResult] = []

        for definition in expandedFeature.scenarios {
            guard case .scenario(let scenario) = definition else { continue }

            // Apply tag filter (combine feature + scenario tags)
            if let filter = tagFilter {
                let allTags = feature.tags + scenario.tags
                if !filter.shouldInclude(tags: allTags) {
                    continue
                }
            }

            let result = await (try run(
                scenario: scenario,
                background: expandedFeature.background,
                feature: feature
            ))
            results.append(result)
        }

        return FeatureResult(
            featureName: feature.name,
            scenarioResults: results
        )
    }

    // MARK: - Private

    private func executeStep(_ step: Step, feature: Feature?) async throws {
        guard let (handler, match) = try registry.match(step) else {
            throw ScenarioRunnerError.undefinedStep(
                step: step,
                feature: feature?.name,
                file: feature?.sourceFile
            )
        }

        do {
            try await handler(match)
        } catch {
            throw ScenarioRunnerError.stepFailed(
                step: step,
                feature: feature?.name,
                scenario: nil,
                underlyingError: error
            )
        }
    }
}
