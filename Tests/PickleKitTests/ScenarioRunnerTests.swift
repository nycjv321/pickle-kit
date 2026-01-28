import Foundation
import Testing
@testable import PickleKit

/// Thread-safe mutable box for test state captured across isolation boundaries.
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

@Suite struct ScenarioRunnerTests {

    let registry: StepRegistry
    let runner: ScenarioRunner

    init() {
        registry = StepRegistry()
        runner = ScenarioRunner(registry: registry)
    }

    // MARK: - Passing Scenarios

    @Test func passingScenario() async throws {
        let log = TestBox<[String]>([])

        registry.given("a setup") { _ in log.value.append("given") }
        registry.when("an action") { _ in log.value.append("when") }
        registry.then("a result") { _ in log.value.append("then") }

        let scenario = Scenario(
            name: "Simple",
            steps: [
                Step(keyword: .given, text: "a setup", sourceLine: 1),
                Step(keyword: .when, text: "an action", sourceLine: 2),
                Step(keyword: .then, text: "a result", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.passed)
        #expect(result.stepsExecuted == 3)
        #expect(log.value == ["given", "when", "then"])
    }

    // MARK: - Background Steps

    @Test func backgroundStepsRunFirst() async throws {
        let log = TestBox<[String]>([])

        registry.step("background step") { _ in log.value.append("bg") }
        registry.step("scenario step") { _ in log.value.append("sc") }

        let background = Background(
            steps: [Step(keyword: .given, text: "background step", sourceLine: 1)]
        )

        let scenario = Scenario(
            name: "With BG",
            steps: [Step(keyword: .when, text: "scenario step", sourceLine: 2)]
        )

        let result = try await runner.run(scenario: scenario, background: background)

        #expect(result.passed)
        #expect(log.value == ["bg", "sc"])
        #expect(result.stepsExecuted == 2)
    }

    // MARK: - Undefined Steps

    @Test func undefinedStepFails() async throws {
        let scenario = Scenario(
            name: "Missing",
            steps: [Step(keyword: .given, text: "undefined step", sourceLine: 5)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(!result.passed)
        #expect(result.error != nil)
        #expect(result.error is ScenarioRunnerError)
    }

    // MARK: - Step Failure

    @Test func stepFailurePropagated() async throws {
        struct TestError: Error {}

        registry.given("will fail") { _ in throw TestError() }

        let scenario = Scenario(
            name: "Failing",
            steps: [Step(keyword: .given, text: "will fail", sourceLine: 10)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(!result.passed)
        #expect(result.error != nil)
    }

    @Test func stepFailureStopsExecution() async throws {
        struct TestError: Error {}
        let log = TestBox<[String]>([])

        registry.given("first") { _ in log.value.append("first") }
        registry.when("fails") { _ in throw TestError() }
        registry.then("never reached") { _ in log.value.append("third") }

        let scenario = Scenario(
            name: "Short circuit",
            steps: [
                Step(keyword: .given, text: "first", sourceLine: 1),
                Step(keyword: .when, text: "fails", sourceLine: 2),
                Step(keyword: .then, text: "never reached", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(!result.passed)
        #expect(log.value == ["first"])
        #expect(result.stepsExecuted == 1)
    }

    // MARK: - Captures in Execution

    @Test func capturesAvailableInHandler() async throws {
        let sum = TestBox(0)

        registry.step("I have (\\d+) items") { match in
            sum.value = Int(match.captures[0])!
        }
        registry.step("I add (\\d+)") { match in
            sum.value += Int(match.captures[0])!
        }
        registry.step("I should have (\\d+)") { match in
            let expected = Int(match.captures[0])!
            guard sum.value == expected else {
                throw NSError(domain: "test", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Expected \(expected) but got \(sum.value)"
                ])
            }
        }

        let scenario = Scenario(
            name: "Math",
            steps: [
                Step(keyword: .given, text: "I have 5 items", sourceLine: 1),
                Step(keyword: .when, text: "I add 3", sourceLine: 2),
                Step(keyword: .then, text: "I should have 8", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)
        #expect(result.passed)
    }

    // MARK: - Feature Execution

    @Test func runFeature() async throws {
        registry.step("something") { _ in }
        registry.step("happens") { _ in }

        let feature = Feature(
            name: "Multi",
            scenarios: [
                .scenario(Scenario(name: "A", steps: [
                    Step(keyword: .given, text: "something"),
                    Step(keyword: .then, text: "happens"),
                ])),
                .scenario(Scenario(name: "B", steps: [
                    Step(keyword: .given, text: "something"),
                    Step(keyword: .then, text: "happens"),
                ])),
            ]
        )

        let result = try await runner.run(feature: feature)

        #expect(result.featureName == "Multi")
        #expect(result.scenarioResults.count == 2)
        #expect(result.allPassed)
        #expect(result.passedCount == 2)
        #expect(result.failedCount == 0)
    }

    @Test func runFeatureWithTagFilter() async throws {
        registry.step(".*") { _ in }

        let feature = Feature(
            name: "Filtered",
            scenarios: [
                .scenario(Scenario(name: "Included", tags: ["smoke"], steps: [
                    Step(keyword: .given, text: "a"),
                ])),
                .scenario(Scenario(name: "Excluded", tags: ["wip"], steps: [
                    Step(keyword: .given, text: "b"),
                ])),
            ]
        )

        let filter = TagFilter(includeTags: ["smoke"])
        let result = try await runner.run(feature: feature, tagFilter: filter)

        #expect(result.scenarioResults.count == 1)
        #expect(result.scenarioResults[0].scenarioName == "Included")
    }

    // MARK: - Scenario Name in Result

    @Test func scenarioNameInResult() async throws {
        registry.step("x") { _ in }

        let scenario = Scenario(name: "My Scenario", steps: [
            Step(keyword: .given, text: "x"),
        ])

        let result = try await runner.run(scenario: scenario)
        #expect(result.scenarioName == "My Scenario")
    }

    // MARK: - Data Table in Handler

    @Test func dataTableAvailableInHandler() async throws {
        let receivedTable = TestBox<DataTable?>(nil)

        registry.step("users:") { match in
            receivedTable.value = match.dataTable
        }

        let table = DataTable(rows: [["name"], ["Alice"], ["Bob"]])
        let scenario = Scenario(
            name: "Tables",
            steps: [Step(keyword: .given, text: "users:", dataTable: table, sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        #expect(result.passed)
        #expect(receivedTable.value != nil)
        #expect(receivedTable.value?.dataRows.count == 2)
    }
}
