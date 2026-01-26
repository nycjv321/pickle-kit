import XCTest
@testable import PickleKit

final class ScenarioRunnerTests: XCTestCase {

    var registry: StepRegistry!
    var runner: ScenarioRunner!

    override func setUp() {
        super.setUp()
        registry = StepRegistry()
        runner = ScenarioRunner(registry: registry)
    }

    // MARK: - Passing Scenarios

    func testPassingScenario() async throws {
        var log: [String] = []

        registry.given("a setup") { _ in log.append("given") }
        registry.when("an action") { _ in log.append("when") }
        registry.then("a result") { _ in log.append("then") }

        let scenario = Scenario(
            name: "Simple",
            steps: [
                Step(keyword: .given, text: "a setup", sourceLine: 1),
                Step(keyword: .when, text: "an action", sourceLine: 2),
                Step(keyword: .then, text: "a result", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.stepsExecuted, 3)
        XCTAssertEqual(log, ["given", "when", "then"])
    }

    // MARK: - Background Steps

    func testBackgroundStepsRunFirst() async throws {
        var log: [String] = []

        registry.step("background step") { _ in log.append("bg") }
        registry.step("scenario step") { _ in log.append("sc") }

        let background = Background(
            steps: [Step(keyword: .given, text: "background step", sourceLine: 1)]
        )

        let scenario = Scenario(
            name: "With BG",
            steps: [Step(keyword: .when, text: "scenario step", sourceLine: 2)]
        )

        let result = try await runner.run(scenario: scenario, background: background)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(log, ["bg", "sc"])
        XCTAssertEqual(result.stepsExecuted, 2)
    }

    // MARK: - Undefined Steps

    func testUndefinedStepFails() async throws {
        let scenario = Scenario(
            name: "Missing",
            steps: [Step(keyword: .given, text: "undefined step", sourceLine: 5)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertFalse(result.passed)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error is ScenarioRunnerError)
    }

    // MARK: - Step Failure

    func testStepFailurePropagated() async throws {
        struct TestError: Error {}

        registry.given("will fail") { _ in throw TestError() }

        let scenario = Scenario(
            name: "Failing",
            steps: [Step(keyword: .given, text: "will fail", sourceLine: 10)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertFalse(result.passed)
        XCTAssertNotNil(result.error)
    }

    func testStepFailureStopsExecution() async throws {
        struct TestError: Error {}
        var log: [String] = []

        registry.given("first") { _ in log.append("first") }
        registry.when("fails") { _ in throw TestError() }
        registry.then("never reached") { _ in log.append("third") }

        let scenario = Scenario(
            name: "Short circuit",
            steps: [
                Step(keyword: .given, text: "first", sourceLine: 1),
                Step(keyword: .when, text: "fails", sourceLine: 2),
                Step(keyword: .then, text: "never reached", sourceLine: 3),
            ]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(log, ["first"])
        XCTAssertEqual(result.stepsExecuted, 1)
    }

    // MARK: - Captures in Execution

    func testCapturesAvailableInHandler() async throws {
        var sum = 0

        registry.step("I have (\\d+) items") { match in
            sum = Int(match.captures[0])!
        }
        registry.step("I add (\\d+)") { match in
            sum += Int(match.captures[0])!
        }
        registry.step("I should have (\\d+)") { match in
            let expected = Int(match.captures[0])!
            guard sum == expected else {
                throw NSError(domain: "test", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Expected \(expected) but got \(sum)"
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
        XCTAssertTrue(result.passed)
    }

    // MARK: - Feature Execution

    func testRunFeature() async throws {
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

        XCTAssertEqual(result.featureName, "Multi")
        XCTAssertEqual(result.scenarioResults.count, 2)
        XCTAssertTrue(result.allPassed)
        XCTAssertEqual(result.passedCount, 2)
        XCTAssertEqual(result.failedCount, 0)
    }

    func testRunFeatureWithTagFilter() async throws {
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

        XCTAssertEqual(result.scenarioResults.count, 1)
        XCTAssertEqual(result.scenarioResults[0].scenarioName, "Included")
    }

    // MARK: - Scenario Name in Result

    func testScenarioNameInResult() async throws {
        registry.step("x") { _ in }

        let scenario = Scenario(name: "My Scenario", steps: [
            Step(keyword: .given, text: "x"),
        ])

        let result = try await runner.run(scenario: scenario)
        XCTAssertEqual(result.scenarioName, "My Scenario")
    }

    // MARK: - Data Table in Handler

    func testDataTableAvailableInHandler() async throws {
        var receivedTable: DataTable?

        registry.step("users:") { match in
            receivedTable = match.dataTable
        }

        let table = DataTable(rows: [["name"], ["Alice"], ["Bob"]])
        let scenario = Scenario(
            name: "Tables",
            steps: [Step(keyword: .given, text: "users:", dataTable: table, sourceLine: 1)]
        )

        let result = try await runner.run(scenario: scenario)

        XCTAssertTrue(result.passed)
        XCTAssertNotNil(receivedTable)
        XCTAssertEqual(receivedTable?.dataRows.count, 2)
    }
}
