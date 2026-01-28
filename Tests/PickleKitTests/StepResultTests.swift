import Foundation
import Testing
@testable import PickleKit

@Suite struct StepResultTests {

    let registry: StepRegistry
    let runner: ScenarioRunner

    init() {
        registry = StepRegistry()
        runner = ScenarioRunner(registry: registry)
    }

    // MARK: - Passing Scenario Step Results

    @Test func passingScenarioHasAllStepsPassed() async throws {
        registry.given("a setup") { _ in }
        registry.when("an action") { _ in }
        registry.then("a result") { _ in }

        let scenario = Scenario(
            name: "All Passing",
            steps: [
                Step(keyword: .given, text: "a setup", sourceLine: 1),
                Step(keyword: .when, text: "an action", sourceLine: 2),
                Step(keyword: .then, text: "a result", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.passed)
        #expect(result.stepResults.count == 3)
        for stepResult in result.stepResults {
            #expect(stepResult.status == .passed)
        }
    }

    @Test func passingStepsHavePositiveDuration() async throws {
        registry.given("a setup") { _ in
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        let scenario = Scenario(
            name: "Timed",
            steps: [Step(keyword: .given, text: "a setup", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.passed)
        #expect(result.stepResults.count == 1)
        #expect(result.stepResults[0].duration > 0)
    }

    @Test func stepResultsContainKeywordAndText() async throws {
        registry.given("I have items") { _ in }
        registry.when("I do something") { _ in }

        let scenario = Scenario(
            name: "Keywords",
            steps: [
                Step(keyword: .given, text: "I have items", sourceLine: 1),
                Step(keyword: .when, text: "I do something", sourceLine: 2),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.stepResults[0].keyword == "Given")
        #expect(result.stepResults[0].text == "I have items")
        #expect(result.stepResults[1].keyword == "When")
        #expect(result.stepResults[1].text == "I do something")
    }

    // MARK: - Failing Scenario Step Results

    @Test func failingScenarioMarksFailedAndSkippedSteps() async throws {
        struct TestError: Error {}

        registry.given("step one") { _ in }
        registry.when("step two fails") { _ in throw TestError() }
        registry.then("step three") { _ in }

        let scenario = Scenario(
            name: "Fail Middle",
            steps: [
                Step(keyword: .given, text: "step one", sourceLine: 1),
                Step(keyword: .when, text: "step two fails", sourceLine: 2),
                Step(keyword: .then, text: "step three", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(!result.passed)
        #expect(result.stepResults.count == 3)
        #expect(result.stepResults[0].status == .passed)
        #expect(result.stepResults[1].status == .failed)
        #expect(result.stepResults[1].error != nil)
        #expect(result.stepResults[2].status == .skipped)
    }

    @Test func failedStepContainsErrorMessage() async throws {
        registry.given("bad step") { _ in
            throw NSError(domain: "test", code: 42, userInfo: [
                NSLocalizedDescriptionKey: "Something went wrong"
            ])
        }

        let scenario = Scenario(
            name: "Error Message",
            steps: [Step(keyword: .given, text: "bad step", sourceLine: 5)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.stepResults.count == 1)
        #expect(result.stepResults[0].status == .failed)
        #expect(result.stepResults[0].error != nil)
    }

    // MARK: - Undefined Step Results

    @Test func undefinedStepMarkedAsUndefined() async throws {
        let scenario = Scenario(
            name: "Undefined",
            steps: [
                Step(keyword: .given, text: "nonexistent step", sourceLine: 10),
                Step(keyword: .then, text: "also skipped", sourceLine: 11),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(!result.passed)
        #expect(result.stepResults.count == 2)
        #expect(result.stepResults[0].status == .undefined)
        #expect(result.stepResults[1].status == .skipped)
    }

    // MARK: - Tags Propagation

    @Test func tagsPropagatedToScenarioResult() async throws {
        registry.given("x") { _ in }

        let scenario = Scenario(
            name: "Tagged",
            tags: ["smoke", "fast"],
            steps: [Step(keyword: .given, text: "x", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.tags == ["smoke", "fast"])
    }

    // MARK: - Scenario Duration

    @Test func scenarioDurationIsPositive() async throws {
        registry.given("a step") { _ in
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        let scenario = Scenario(
            name: "Duration",
            steps: [Step(keyword: .given, text: "a step", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.duration > 0)
    }

    // MARK: - Feature-Level Enrichment

    @Test func featureResultContainsTagsAndSourceFile() async throws {
        registry.step("something") { _ in }

        let feature = Feature(
            name: "Tagged Feature",
            tags: ["integration"],
            scenarios: [
                .scenario(Scenario(name: "A", steps: [
                    Step(keyword: .given, text: "something"),
                ])),
            ],
            sourceFile: "test.feature"
        )

        let result = try await runner.run(feature: feature)

        #expect(result.tags == ["integration"])
        #expect(result.sourceFile == "test.feature")
        #expect(result.duration >= 0)
    }

    @Test func featureResultStepCounts() async throws {
        struct TestError: Error {}

        registry.step("passes") { _ in }
        registry.step("fails") { _ in throw TestError() }

        let feature = Feature(
            name: "Mixed",
            scenarios: [
                .scenario(Scenario(name: "Good", steps: [
                    Step(keyword: .given, text: "passes", sourceLine: 1),
                    Step(keyword: .then, text: "passes", sourceLine: 2),
                ])),
                .scenario(Scenario(name: "Bad", steps: [
                    Step(keyword: .given, text: "passes", sourceLine: 3),
                    Step(keyword: .when, text: "fails", sourceLine: 4),
                    Step(keyword: .then, text: "passes", sourceLine: 5),
                ])),
            ]
        )

        let result = try await runner.run(feature: feature)

        #expect(result.totalStepCount == 5)
        #expect(result.passedStepCount == 3)
        #expect(result.failedStepCount == 1)
        #expect(result.skippedStepCount == 1)
    }

    // MARK: - Background Steps in Step Results

    @Test func backgroundStepsIncludedInStepResults() async throws {
        registry.step("background step") { _ in }
        registry.step("scenario step") { _ in }

        let background = Background(
            steps: [Step(keyword: .given, text: "background step", sourceLine: 1)]
        )

        let scenario = Scenario(
            name: "With BG",
            steps: [Step(keyword: .when, text: "scenario step", sourceLine: 2)]
        )

        let result = try await runner.run(scenario: scenario, background: background)

        #expect(result.passed)
        #expect(result.stepResults.count == 2)
        #expect(result.stepResults[0].text == "background step")
        #expect(result.stepResults[1].text == "scenario step")
    }

    // MARK: - Backward Compatibility

    @Test func scenarioResultDefaultsPreserved() {
        let result = ScenarioResult(scenarioName: "Test", passed: true, stepsExecuted: 3)
        #expect(result.tags == [])
        #expect(result.stepResults == [])
        #expect(result.duration == 0)
    }

    @Test func featureResultDefaultsPreserved() {
        let result = FeatureResult(featureName: "Test", scenarioResults: [])
        #expect(result.tags == [])
        #expect(result.sourceFile == nil)
        #expect(result.duration == 0)
    }
}
