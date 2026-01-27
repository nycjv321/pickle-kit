import XCTest
@testable import PickleKit

final class HTMLReportGeneratorTests: XCTestCase {

    private var generator: HTMLReportGenerator!

    override func setUp() {
        super.setUp()
        generator = HTMLReportGenerator()
    }

    // MARK: - Helpers

    private func makeSampleResult() -> TestRunResult {
        let passingSteps = [
            StepResult(keyword: "Given", text: "a setup", status: .passed, duration: 0.001, sourceLine: 1),
            StepResult(keyword: "When", text: "an action", status: .passed, duration: 0.002, sourceLine: 2),
            StepResult(keyword: "Then", text: "a result", status: .passed, duration: 0.001, sourceLine: 3),
        ]

        let failingSteps = [
            StepResult(keyword: "Given", text: "a precondition", status: .passed, duration: 0.001, sourceLine: 5),
            StepResult(keyword: "When", text: "something breaks", status: .failed, duration: 0.003, error: "Expected 5 but got 3", sourceLine: 6),
            StepResult(keyword: "Then", text: "never reached", status: .skipped, sourceLine: 7),
        ]

        let passingScenario = ScenarioResult(
            scenarioName: "Happy Path",
            passed: true,
            stepsExecuted: 3,
            tags: ["smoke"],
            stepResults: passingSteps,
            duration: 0.004
        )

        let failingScenario = ScenarioResult(
            scenarioName: "Error Case",
            passed: false,
            error: NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test failed"]),
            stepsExecuted: 1,
            tags: ["regression"],
            stepResults: failingSteps,
            duration: 0.004
        )

        let feature = FeatureResult(
            featureName: "User Login",
            scenarioResults: [passingScenario, failingScenario],
            tags: ["auth"],
            sourceFile: "login.feature",
            duration: 0.008
        )

        return TestRunResult(
            featureResults: [feature],
            startTime: Date(timeIntervalSince1970: 1000000),
            endTime: Date(timeIntervalSince1970: 1000001)
        )
    }

    // MARK: - HTML Structure

    func testGeneratesValidHTMLStructure() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<html lang=\"en\">"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("<head>"))
        XCTAssertTrue(html.contains("</head>"))
        XCTAssertTrue(html.contains("<body>"))
        XCTAssertTrue(html.contains("</body>"))
    }

    func testContainsInlineCSS() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("</style>"))
    }

    func testContainsInlineJS() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("<script>"))
        XCTAssertTrue(html.contains("expandAll"))
        XCTAssertTrue(html.contains("collapseAll"))
        XCTAssertTrue(html.contains("filterStatus"))
    }

    // MARK: - Feature and Scenario Content

    func testContainsFeatureName() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("User Login"))
    }

    func testContainsScenarioNames() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("Happy Path"))
        XCTAssertTrue(html.contains("Error Case"))
    }

    func testContainsStepText() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("a setup"))
        XCTAssertTrue(html.contains("an action"))
        XCTAssertTrue(html.contains("something breaks"))
    }

    func testContainsErrorMessages() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("Expected 5 but got 3"))
    }

    // MARK: - Summary Counts

    func testSummaryShowsFeatureCount() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        // Features summary: 1 total, 0 passed (because it has a failing scenario), 1 failed
        XCTAssertTrue(html.contains("Features"))
        XCTAssertTrue(html.contains("Scenarios"))
        XCTAssertTrue(html.contains("Steps"))
    }

    func testSummaryShowsCorrectScenarioCounts() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        // 1 passed, 1 failed scenario
        XCTAssertTrue(html.contains("1 passed, 1 failed"))
    }

    // MARK: - CSS Classes for Statuses

    func testContainsStatusCSSClasses() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("status-passed"))
        XCTAssertTrue(html.contains("status-failed"))
        XCTAssertTrue(html.contains("class=\"step-row passed\""))
        XCTAssertTrue(html.contains("class=\"step-row failed\""))
        XCTAssertTrue(html.contains("class=\"step-row skipped\""))
    }

    func testFailedScenarioIsOpenByDefault() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        // Failed scenarios should have `open` attribute
        XCTAssertTrue(html.contains("data-status=\"failed\" open"))
    }

    func testPassingScenarioIsClosedByDefault() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        // Passing scenarios should NOT have `open` attribute
        // They should have data-status="passed"> (without open)
        XCTAssertTrue(html.contains("data-status=\"passed\">"))
    }

    // MARK: - Tags

    func testContainsFeatureTags() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("@auth"))
    }

    func testContainsScenarioTags() {
        let result = makeSampleResult()
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("@smoke"))
        XCTAssertTrue(html.contains("@regression"))
    }

    // MARK: - HTML Escaping

    func testHTMLEscapesSpecialCharacters() {
        let feature = FeatureResult(
            featureName: "Test <script>alert('xss')</script>",
            scenarioResults: [
                ScenarioResult(
                    scenarioName: "Scenario with \"quotes\" & <brackets>",
                    passed: true,
                    stepsExecuted: 1,
                    stepResults: [
                        StepResult(keyword: "Given", text: "a step with <html> & \"entities\"", status: .passed, duration: 0.001, sourceLine: 1)
                    ],
                    duration: 0.001
                )
            ]
        )

        let result = TestRunResult(
            featureResults: [feature],
            startTime: Date(),
            endTime: Date()
        )

        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("&lt;script&gt;"))
        XCTAssertTrue(html.contains("&amp;"))
        XCTAssertTrue(html.contains("&quot;quotes&quot;"))
        XCTAssertFalse(html.contains("<script>alert"))
    }

    // MARK: - Write to File

    func testWriteReportToFile() throws {
        let result = makeSampleResult()
        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("pickle-test-report-\(UUID().uuidString).html")

        try generator.write(result: result, to: path)

        let contents = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(contents.contains("<!DOCTYPE html>"))
        XCTAssertTrue(contents.contains("User Login"))

        // Clean up
        try? FileManager.default.removeItem(atPath: path)
    }

    func testWriteCreatesIntermediateDirectories() throws {
        let result = makeSampleResult()
        let tempDir = NSTemporaryDirectory()
        let nestedDir = (tempDir as NSString).appendingPathComponent("pickle-test-\(UUID().uuidString)/build")
        let path = (nestedDir as NSString).appendingPathComponent("report.html")

        // Directory does not exist yet
        XCTAssertFalse(FileManager.default.fileExists(atPath: nestedDir))

        try generator.write(result: result, to: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(contents.contains("<!DOCTYPE html>"))

        // Clean up
        let rootDir = (tempDir as NSString).appendingPathComponent(
            (nestedDir as NSString).lastPathComponent
        )
        try? FileManager.default.removeItem(atPath: (nestedDir as NSString).deletingLastPathComponent)
    }

    func testWriteToDeeplyNestedPath() throws {
        let result = makeSampleResult()
        let tempDir = NSTemporaryDirectory()
        let uuid = UUID().uuidString
        let path = (tempDir as NSString).appendingPathComponent("pickle-\(uuid)/a/b/c/report.html")

        try generator.write(result: result, to: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        // Clean up
        try? FileManager.default.removeItem(atPath: (tempDir as NSString).appendingPathComponent("pickle-\(uuid)"))
    }

    // MARK: - Empty Result

    func testEmptyResultGeneratesValidHTML() {
        let result = TestRunResult(featureResults: [], startTime: Date(), endTime: Date())
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("</html>"))
        XCTAssertTrue(html.contains("Features"))
    }

    // MARK: - Undefined Step Status

    func testUndefinedStepCSSClass() {
        let feature = FeatureResult(
            featureName: "Undefined Feature",
            scenarioResults: [
                ScenarioResult(
                    scenarioName: "Undefined Scenario",
                    passed: false,
                    stepsExecuted: 0,
                    stepResults: [
                        StepResult(keyword: "Given", text: "undefined step", status: .undefined, error: "No matching step definition", sourceLine: 1)
                    ],
                    duration: 0.001
                )
            ]
        )

        let result = TestRunResult(featureResults: [feature], startTime: Date(), endTime: Date())
        let html = generator.generate(from: result)

        XCTAssertTrue(html.contains("class=\"step-row undefined\""))
    }

    // MARK: - Report Result Collector

    func testCollectorGroupsByFeature() {
        let collector = ReportResultCollector()

        let scenario1 = ScenarioResult(scenarioName: "S1", passed: true, stepsExecuted: 1)
        let scenario2 = ScenarioResult(scenarioName: "S2", passed: true, stepsExecuted: 1)
        let scenario3 = ScenarioResult(scenarioName: "S3", passed: false, stepsExecuted: 0)

        collector.record(scenarioResult: scenario1, featureName: "Feature A", featureTags: ["tag1"])
        collector.record(scenarioResult: scenario2, featureName: "Feature A", featureTags: ["tag1"])
        collector.record(scenarioResult: scenario3, featureName: "Feature B", featureTags: ["tag2"])

        let result = collector.buildTestRunResult()

        XCTAssertEqual(result.featureResults.count, 2)
        XCTAssertEqual(result.featureResults[0].featureName, "Feature A")
        XCTAssertEqual(result.featureResults[0].scenarioResults.count, 2)
        XCTAssertEqual(result.featureResults[1].featureName, "Feature B")
        XCTAssertEqual(result.featureResults[1].scenarioResults.count, 1)
    }

    func testCollectorPreservesFeatureOrder() {
        let collector = ReportResultCollector()

        collector.record(scenarioResult: ScenarioResult(scenarioName: "S1", passed: true), featureName: "Zebra")
        collector.record(scenarioResult: ScenarioResult(scenarioName: "S2", passed: true), featureName: "Alpha")
        collector.record(scenarioResult: ScenarioResult(scenarioName: "S3", passed: true), featureName: "Zebra")

        let result = collector.buildTestRunResult()

        XCTAssertEqual(result.featureResults.count, 2)
        XCTAssertEqual(result.featureResults[0].featureName, "Zebra")
        XCTAssertEqual(result.featureResults[1].featureName, "Alpha")
    }

    func testCollectorReset() {
        let collector = ReportResultCollector()

        collector.record(scenarioResult: ScenarioResult(scenarioName: "S1", passed: true), featureName: "F1")
        collector.reset()

        let result = collector.buildTestRunResult()
        XCTAssertEqual(result.featureResults.count, 0)
    }

    // MARK: - TestRunResult Aggregations

    func testTestRunResultAggregations() {
        let feature1 = FeatureResult(
            featureName: "F1",
            scenarioResults: [
                ScenarioResult(scenarioName: "S1", passed: true, stepsExecuted: 2,
                    stepResults: [
                        StepResult(keyword: "Given", text: "a", status: .passed, sourceLine: 1),
                        StepResult(keyword: "Then", text: "b", status: .passed, sourceLine: 2),
                    ]),
                ScenarioResult(scenarioName: "S2", passed: false, stepsExecuted: 1,
                    stepResults: [
                        StepResult(keyword: "Given", text: "c", status: .passed, sourceLine: 3),
                        StepResult(keyword: "When", text: "d", status: .failed, error: "err", sourceLine: 4),
                        StepResult(keyword: "Then", text: "e", status: .skipped, sourceLine: 5),
                    ]),
            ]
        )

        let feature2 = FeatureResult(
            featureName: "F2",
            scenarioResults: [
                ScenarioResult(scenarioName: "S3", passed: true, stepsExecuted: 1,
                    stepResults: [
                        StepResult(keyword: "Given", text: "f", status: .passed, sourceLine: 1),
                    ]),
            ]
        )

        let result = TestRunResult(
            featureResults: [feature1, feature2],
            startTime: Date(timeIntervalSince1970: 100),
            endTime: Date(timeIntervalSince1970: 105)
        )

        XCTAssertEqual(result.totalFeatureCount, 2)
        XCTAssertEqual(result.passedFeatureCount, 1) // F2 only
        XCTAssertEqual(result.failedFeatureCount, 1) // F1

        XCTAssertEqual(result.totalScenarioCount, 3)
        XCTAssertEqual(result.passedScenarioCount, 2)
        XCTAssertEqual(result.failedScenarioCount, 1)

        XCTAssertEqual(result.totalStepCount, 6)
        XCTAssertEqual(result.passedStepCount, 4) // a, b, c, f
        XCTAssertEqual(result.failedStepCount, 1) // d
        XCTAssertEqual(result.skippedStepCount, 1) // e

        XCTAssertEqual(result.duration, 5.0, accuracy: 0.001)
    }
}
