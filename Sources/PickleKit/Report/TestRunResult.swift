import Foundation

// MARK: - Test Run Result

/// Aggregated results for an entire test run across all features.
public struct TestRunResult: Sendable {
    public let featureResults: [FeatureResult]
    public let startTime: Date
    public let endTime: Date

    public init(featureResults: [FeatureResult], startTime: Date, endTime: Date) {
        self.featureResults = featureResults
        self.startTime = startTime
        self.endTime = endTime
    }

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    // MARK: - Feature Aggregations

    public var totalFeatureCount: Int { featureResults.count }
    public var passedFeatureCount: Int { featureResults.filter(\.allPassed).count }
    public var failedFeatureCount: Int { featureResults.filter { !$0.allPassed }.count }

    // MARK: - Scenario Aggregations

    public var totalScenarioCount: Int {
        featureResults.reduce(0) { $0 + $1.scenarioResults.count }
    }

    public var passedScenarioCount: Int {
        featureResults.reduce(0) { $0 + $1.passedCount }
    }

    public var failedScenarioCount: Int {
        featureResults.reduce(0) { $0 + $1.failedCount }
    }

    public var skippedScenarioCount: Int {
        featureResults.reduce(0) { $0 + $1.skippedCount }
    }

    // MARK: - Step Aggregations

    public var totalStepCount: Int {
        featureResults.reduce(0) { $0 + $1.totalStepCount }
    }

    public var passedStepCount: Int {
        featureResults.reduce(0) { $0 + $1.passedStepCount }
    }

    public var failedStepCount: Int {
        featureResults.reduce(0) { $0 + $1.failedStepCount }
    }

    public var skippedStepCount: Int {
        featureResults.reduce(0) { $0 + $1.skippedStepCount }
    }

    public var undefinedStepCount: Int {
        featureResults.reduce(0) { $0 + $1.undefinedStepCount }
    }
}
