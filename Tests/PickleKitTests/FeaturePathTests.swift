import XCTest
@testable import PickleKit

final class FeaturePathTests: XCTestCase {

    // MARK: - Path Parsing

    func testParseSimpleFilePath() throws {
        let fixtureDir = try fixturesDirectory()
        let path = (fixtureDir as NSString).appendingPathComponent("basic.feature")
        let result = FeaturePath.parse(path)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, path)
        XCTAssertEqual(result?.lines, [])
        XCTAssertFalse(result?.isDirectory ?? true)
    }

    func testParseFilePathWithOneLine() {
        let result = FeaturePath.parse("/tmp/login.feature:10")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/tmp/login.feature")
        XCTAssertEqual(result?.lines, [10])
        XCTAssertFalse(result?.isDirectory ?? true)
    }

    func testParseFilePathWithMultipleLines() {
        let result = FeaturePath.parse("/tmp/login.feature:10:25")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/tmp/login.feature")
        XCTAssertEqual(result?.lines, [10, 25])
    }

    func testParseDirectoryPath() throws {
        let fixtureDir = try fixturesDirectory()
        let result = FeaturePath.parse(fixtureDir)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isDirectory ?? false)
    }

    func testParseDirectoryPathWithTrailingSlash() {
        // Trailing "/" should mark as directory even if path doesn't exist
        let result = FeaturePath.parse("/tmp/nonexistent_features/")

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isDirectory ?? false)
    }

    func testParseAbsolutePath() {
        let result = FeaturePath.parse("/absolute/path/to/file.feature")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/absolute/path/to/file.feature")
    }

    func testParseRelativePath() {
        let result = FeaturePath.parse("relative/file.feature", relativeTo: "/base/dir")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/base/dir/relative/file.feature")
    }

    func testParseEmptyString() {
        let result = FeaturePath.parse("")
        XCTAssertNil(result)
    }

    func testParseWhitespaceOnlyString() {
        let result = FeaturePath.parse("   ")
        XCTAssertNil(result)
    }

    func testParseListMultiplePaths() {
        let results = FeaturePath.parseList(
            "/tmp/a.feature /tmp/b.feature:5",
            relativeTo: "/base"
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].path, "/tmp/a.feature")
        XCTAssertEqual(results[0].lines, [])
        XCTAssertEqual(results[1].path, "/tmp/b.feature")
        XCTAssertEqual(results[1].lines, [5])
    }

    func testParseListEmptyString() {
        let results = FeaturePath.parseList("")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Environment Variable

    func testFromEnvironmentWhenUnset() {
        // CUCUMBER_FEATURES is not set in the test environment by default
        let result = FeaturePath.fromEnvironment()
        // This test verifies behavior when the env var is absent.
        // We can't control env vars in-process, so just verify the method is callable
        // and returns nil when not set (which is the default test state).
        if ProcessInfo.processInfo.environment["CUCUMBER_FEATURES"] == nil {
            XCTAssertNil(result)
        }
    }

    // MARK: - GherkinParser Path Methods

    func testParseFileStoringFullPath() throws {
        let fixtureDir = try fixturesDirectory()
        let fullPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let feature = try parser.parseFileStoringFullPath(at: fullPath)

        XCTAssertEqual(feature.name, "Basic arithmetic")
        XCTAssertEqual(feature.sourceFile, fullPath)
        XCTAssertEqual(feature.scenarios.count, 2)
    }

    func testParseFileStoringFullPathPreservesFullPath() throws {
        let fixtureDir = try fixturesDirectory()
        let fullPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()

        // parseFile stores only lastPathComponent
        let featureShort = try parser.parseFile(at: fullPath)
        XCTAssertEqual(featureShort.sourceFile, "basic.feature")

        // parseFileStoringFullPath stores the full path
        let featureFull = try parser.parseFileStoringFullPath(at: fullPath)
        XCTAssertEqual(featureFull.sourceFile, fullPath)
    }

    func testParseDirectory() throws {
        let fixtureDir = try fixturesDirectory()

        let parser = GherkinParser()
        let features = try parser.parseDirectory(at: fixtureDir)

        // Should find all .feature files in Fixtures/
        XCTAssertGreaterThanOrEqual(features.count, 6)

        // Should be sorted alphabetically
        let fileNames = features.compactMap { ($0.sourceFile as NSString?)?.lastPathComponent }
        XCTAssertEqual(fileNames, fileNames.sorted())

        // Each feature should have the full path as sourceFile
        for feature in features {
            XCTAssertNotNil(feature.sourceFile)
            XCTAssertTrue(feature.sourceFile?.hasPrefix(fixtureDir) ?? false)
        }
    }

    func testParsePaths() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [6], isDirectory: false)
        ]

        let result = try parser.parsePaths(paths)

        XCTAssertEqual(result.features.count, 1)
        XCTAssertEqual(result.features[0].name, "Basic arithmetic")
        XCTAssertEqual(result.lineFilters[basicPath], Set([6]))
    }

    func testParsePathsDeduplicates() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [6], isDirectory: false),
            FeaturePath(path: basicPath, lines: [11], isDirectory: false),
        ]

        let result = try parser.parsePaths(paths)

        // Should only parse the file once
        XCTAssertEqual(result.features.count, 1)
        // But merge line filters
        XCTAssertEqual(result.lineFilters[basicPath], Set([6, 11]))
    }

    func testParsePathsDirectory() throws {
        let fixtureDir = try fixturesDirectory()

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: fixtureDir, lines: [], isDirectory: true)
        ]

        let result = try parser.parsePaths(paths)

        XCTAssertGreaterThanOrEqual(result.features.count, 6)
        XCTAssertTrue(result.lineFilters.isEmpty)
    }

    func testParsePathsNoLineFiltersForFileWithoutLines() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [], isDirectory: false)
        ]

        let result = try parser.parsePaths(paths)

        XCTAssertEqual(result.features.count, 1)
        XCTAssertTrue(result.lineFilters.isEmpty)
    }

    // MARK: - Line Filtering Logic

    func testLineFilterMatchesExactScenarioLine() throws {
        // basic.feature: Scenario: Addition is at line 6
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        // Line 6 is the exact "Scenario: Addition" line
        let matched = scenariosMatchingLines(scenarios, allowedLines: [6], feature: feature)
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].name, "Addition")
    }

    func testLineFilterMatchesStepWithinScenario() throws {
        // basic.feature: "When I add 3" is at line 8, within Scenario: Addition (line 6)
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [8], feature: feature)
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].name, "Addition")
    }

    func testLineFilterMatchesSecondScenario() throws {
        // basic.feature: Scenario: Subtraction is at line 11
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [11], feature: feature)
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].name, "Subtraction")
    }

    func testLineFilterNoMatchForFeatureLine() throws {
        // basic.feature: line 1 is "Feature: Basic arithmetic"
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        // Line 1 is the Feature line — no scenario starts at or before it
        // (first scenario is at line 6)
        let matched = scenariosMatchingLines(scenarios, allowedLines: [1], feature: feature)
        XCTAssertTrue(matched.isEmpty)
    }

    func testLineFilterNoMatchForBackgroundLine() throws {
        // with_background.feature: Background is at line 2, scenarios at 6 and 10
        let fixtureDir = try fixturesDirectory()
        let path = (fixtureDir as NSString).appendingPathComponent("with_background.feature")
        let parser = GherkinParser()
        let feature = try parser.parseFileStoringFullPath(at: path)
        let expanded = OutlineExpander().expand(feature)
        let scenarios = expandedScenarios(from: expanded)

        // Line 3 is within the Background block (before any scenario)
        let matched = scenariosMatchingLines(scenarios, allowedLines: [3], feature: expanded)
        XCTAssertTrue(matched.isEmpty)
    }

    func testLineFilterWithMultipleAllowedLines() throws {
        // basic.feature: Addition at line 6, Subtraction at line 11
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [6, 11], feature: feature)
        XCTAssertEqual(matched.count, 2)
        let names = Set(matched.map(\.name))
        XCTAssertTrue(names.contains("Addition"))
        XCTAssertTrue(names.contains("Subtraction"))
    }

    func testLineFilterPastEndOfFile() throws {
        // basic.feature has 15 lines; line 100 should match the last scenario
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [100], feature: feature)
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched[0].name, "Subtraction")
    }

    // MARK: - Equatable

    func testFeaturePathEquatable() {
        let a = FeaturePath(path: "/tmp/a.feature", lines: [10], isDirectory: false)
        let b = FeaturePath(path: "/tmp/a.feature", lines: [10], isDirectory: false)
        let c = FeaturePath(path: "/tmp/a.feature", lines: [20], isDirectory: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Helpers

    private func fixturesDirectory() throws -> String {
        let url = Bundle.module.url(forResource: "basic", withExtension: "feature", subdirectory: "Fixtures")!
        return url.deletingLastPathComponent().path
    }

    private func parseBasicFeature() throws -> Feature {
        let fixtureDir = try fixturesDirectory()
        let path = (fixtureDir as NSString).appendingPathComponent("basic.feature")
        let parser = GherkinParser()
        let feature = try parser.parseFileStoringFullPath(at: path)
        return OutlineExpander().expand(feature)
    }

    private func expandedScenarios(from feature: Feature) -> [Scenario] {
        feature.scenarios.compactMap {
            if case .scenario(let s) = $0 { return s }
            return nil
        }
    }

    /// Replicates the line-matching algorithm from GherkinTestCase.
    /// A scenario matches a line if the line falls within its definition range.
    private func scenariosMatchingLines(
        _ scenarios: [Scenario],
        allowedLines: Set<Int>,
        feature: Feature
    ) -> [Scenario] {
        let allSourceLines = feature.scenarios.map(\.sourceLine).sorted()

        return scenarios.filter { scenario in
            for line in allowedLines {
                if let matchedLine = allSourceLines.last(where: { $0 <= line }) {
                    if matchedLine == scenario.sourceLine {
                        return true
                    }
                }
            }
            return false
        }
    }
}
