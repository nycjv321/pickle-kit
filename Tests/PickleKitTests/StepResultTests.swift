import XCTest
@testable import PickleKit

final class StepResultTests: XCTestCase {

    var registry: StepRegistry!
    var runner: ScenarioRunner!

    override func setUp() {
        super.setUp()
        registry = StepRegistry()
        runner = ScenarioRunner(registry: registry)
    }

    // MARK: - Passing Scenario Step Results

    func testPassingScenarioHasAllStepsPassed() async throws {
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

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.stepResults.count, 3)
        for stepResult in result.stepResults {
            XCTAssertEqual(stepResult.status, .passed)
        }
    }

    func testPassingStepsHavePositiveDuration() async throws {
        registry.given("a setup") { _ in
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        let scenario = Scenario(
            name: "Timed",
            steps: [Step(keyword: .given, text: "a setup", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.stepResults.count, 1)
        XCTAssertGreaterThan(result.stepResults[0].duration, 0)
    }

    func testStepResultsContainKeywordAndText() async throws {
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

        XCTAssertEqual(result.stepResults[0].keyword, "Given")
        XCTAssertEqual(result.stepResults[0].text, "I have items")
        XCTAssertEqual(result.stepResults[1].keyword, "When")
        XCTAssertEqual(result.stepResults[1].text, "I do something")
    }

    // MARK: - Failing Scenario Step Results

    func testFailingScenarioMarksFailedAndSkippedSteps() async throws {
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

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.stepResults.count, 3)
        XCTAssertEqual(result.stepResults[0].status, .passed)
        XCTAssertEqual(result.stepResults[1].status, .failed)
        XCTAssertNotNil(result.stepResults[1].error)
        XCTAssertEqual(result.stepResults[2].status, .skipped)
    }

    func testFailedStepContainsErrorMessage() async throws {
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

        XCTAssertEqual(result.stepResults.count, 1)
        XCTAssertEqual(result.stepResults[0].status, .failed)
        XCTAssertNotNil(result.stepResults[0].error)
    }

    // MARK: - Undefined Step Results

    func testUndefinedStepMarkedAsUndefined() async throws {
        // No steps registered — the step will be undefined
        let scenario = Scenario(
            name: "Undefined",
            steps: [
                Step(keyword: .given, text: "nonexistent step", sourceLine: 10),
                Step(keyword: .then, text: "also skipped", sourceLine: 11),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.stepResults.count, 2)
        XCTAssertEqual(result.stepResults[0].status, .undefined)
        XCTAssertEqual(result.stepResults[1].status, .skipped)
    }

    // MARK: - Tags Propagation

    func testTagsPropagatedToScenarioResult() async throws {
        registry.given("x") { _ in }

        let scenario = Scenario(
            name: "Tagged",
            tags: ["smoke", "fast"],
            steps: [Step(keyword: .given, text: "x", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertEqual(result.tags, ["smoke", "fast"])
    }

    // MARK: - Scenario Duration

    func testScenarioDurationIsPositive() async throws {
        registry.given("a step") { _ in
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        let scenario = Scenario(
            name: "Duration",
            steps: [Step(keyword: .given, text: "a step", sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertGreaterThan(result.duration, 0)
    }

    // MARK: - Feature-Level Enrichment

    func testFeatureResultContainsTagsAndSourceFile() async throws {
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

        XCTAssertEqual(result.tags, ["integration"])
        XCTAssertEqual(result.sourceFile, "test.feature")
        XCTAssertGreaterThanOrEqual(result.duration, 0)
    }

    func testFeatureResultStepCounts() async throws {
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

        XCTAssertEqual(result.totalStepCount, 5)
        XCTAssertEqual(result.passedStepCount, 3) // 2 from Good + 1 from Bad
        XCTAssertEqual(result.failedStepCount, 1)
        XCTAssertEqual(result.skippedStepCount, 1)
    }

    // MARK: - Background Steps in Step Results

    func testBackgroundStepsIncludedInStepResults() async throws {
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

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.stepResults.count, 2)
        XCTAssertEqual(result.stepResults[0].text, "background step")
        XCTAssertEqual(result.stepResults[1].text, "scenario step")
    }

    // MARK: - Backward Compatibility

    func testScenarioResultDefaultsPreserved() {
        // Verify the existing initializer still works with just the original fields
        let result = ScenarioResult(scenarioName: "Test", passed: true, stepsExecuted: 3)
        XCTAssertEqual(result.tags, [])
        XCTAssertEqual(result.stepResults, [])
        XCTAssertEqual(result.duration, 0)
    }

    func testFeatureResultDefaultsPreserved() {
        let result = FeatureResult(featureName: "Test", scenarioResults: [])
        XCTAssertEqual(result.tags, [])
        XCTAssertNil(result.sourceFile)
        XCTAssertEqual(result.duration, 0)
    }
}
