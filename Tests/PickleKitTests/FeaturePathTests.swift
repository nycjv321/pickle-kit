import Testing
import Foundation
@testable import PickleKit

@Suite
struct FeaturePathTests {

    // MARK: - Path Parsing

    @Test func parseSimpleFilePath() throws {
        let fixtureDir = try fixturesDirectory()
        let path = (fixtureDir as NSString).appendingPathComponent("basic.feature")
        let result = FeaturePath.parse(path)

        #expect(result != nil)
        #expect(result?.path == path)
        #expect(result?.lines == [])
        #expect(!(result?.isDirectory ?? true))
    }

    @Test func parseFilePathWithOneLine() {
        let result = FeaturePath.parse("/tmp/login.feature:10")

        #expect(result != nil)
        #expect(result?.path == "/tmp/login.feature")
        #expect(result?.lines == [10])
        #expect(!(result?.isDirectory ?? true))
    }

    @Test func parseFilePathWithMultipleLines() {
        let result = FeaturePath.parse("/tmp/login.feature:10:25")

        #expect(result != nil)
        #expect(result?.path == "/tmp/login.feature")
        #expect(result?.lines == [10, 25])
    }

    @Test func parseDirectoryPath() throws {
        let fixtureDir = try fixturesDirectory()
        let result = FeaturePath.parse(fixtureDir)

        #expect(result != nil)
        #expect(result?.isDirectory ?? false)
    }

    @Test func parseDirectoryPathWithTrailingSlash() {
        let result = FeaturePath.parse("/tmp/nonexistent_features/")

        #expect(result != nil)
        #expect(result?.isDirectory ?? false)
    }

    @Test func parseAbsolutePath() {
        let result = FeaturePath.parse("/absolute/path/to/file.feature")

        #expect(result != nil)
        #expect(result?.path == "/absolute/path/to/file.feature")
    }

    @Test func parseRelativePath() {
        let result = FeaturePath.parse("relative/file.feature", relativeTo: "/base/dir")

        #expect(result != nil)
        #expect(result?.path == "/base/dir/relative/file.feature")
    }

    @Test func parseEmptyString() {
        let result = FeaturePath.parse("")
        #expect(result == nil)
    }

    @Test func parseWhitespaceOnlyString() {
        let result = FeaturePath.parse("   ")
        #expect(result == nil)
    }

    @Test func parseListMultiplePaths() {
        let results = FeaturePath.parseList(
            "/tmp/a.feature /tmp/b.feature:5",
            relativeTo: "/base"
        )

        #expect(results.count == 2)
        #expect(results[0].path == "/tmp/a.feature")
        #expect(results[0].lines == [])
        #expect(results[1].path == "/tmp/b.feature")
        #expect(results[1].lines == [5])
    }

    @Test func parseListEmptyString() {
        let results = FeaturePath.parseList("")
        #expect(results.isEmpty)
    }

    // MARK: - Environment Variable

    @Test func fromEnvironmentWhenUnset() {
        let result = FeaturePath.fromEnvironment()
        if ProcessInfo.processInfo.environment["CUCUMBER_FEATURES"] == nil {
            #expect(result == nil)
        }
    }

    // MARK: - GherkinParser Path Methods

    @Test func parseFileStoringFullPath() throws {
        let fixtureDir = try fixturesDirectory()
        let fullPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let feature = try parser.parseFileStoringFullPath(at: fullPath)

        #expect(feature.name == "Basic arithmetic")
        #expect(feature.sourceFile == fullPath)
        #expect(feature.scenarios.count == 2)
    }

    @Test func parseFileStoringFullPathPreservesFullPath() throws {
        let fixtureDir = try fixturesDirectory()
        let fullPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()

        let featureShort = try parser.parseFile(at: fullPath)
        #expect(featureShort.sourceFile == "basic.feature")

        let featureFull = try parser.parseFileStoringFullPath(at: fullPath)
        #expect(featureFull.sourceFile == fullPath)
    }

    @Test func parseDirectory() throws {
        let fixtureDir = try fixturesDirectory()

        let parser = GherkinParser()
        let features = try parser.parseDirectory(at: fixtureDir)

        #expect(features.count >= 6)

        let fileNames = features.compactMap { ($0.sourceFile as NSString?)?.lastPathComponent }
        #expect(fileNames == fileNames.sorted())

        for feature in features {
            #expect(feature.sourceFile != nil)
            #expect(feature.sourceFile?.hasPrefix(fixtureDir) ?? false)
        }
    }

    @Test func parsePaths() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [6], isDirectory: false)
        ]

        let result = try parser.parsePaths(paths)

        #expect(result.features.count == 1)
        #expect(result.features[0].name == "Basic arithmetic")
        #expect(result.lineFilters[basicPath] == Set([6]))
    }

    @Test func parsePathsDeduplicates() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [6], isDirectory: false),
            FeaturePath(path: basicPath, lines: [11], isDirectory: false),
        ]

        let result = try parser.parsePaths(paths)

        #expect(result.features.count == 1)
        #expect(result.lineFilters[basicPath] == Set([6, 11]))
    }

    @Test func parsePathsDirectory() throws {
        let fixtureDir = try fixturesDirectory()

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: fixtureDir, lines: [], isDirectory: true)
        ]

        let result = try parser.parsePaths(paths)

        #expect(result.features.count >= 6)
        #expect(result.lineFilters.isEmpty)
    }

    @Test func parsePathsNoLineFiltersForFileWithoutLines() throws {
        let fixtureDir = try fixturesDirectory()
        let basicPath = (fixtureDir as NSString).appendingPathComponent("basic.feature")

        let parser = GherkinParser()
        let paths = [
            FeaturePath(path: basicPath, lines: [], isDirectory: false)
        ]

        let result = try parser.parsePaths(paths)

        #expect(result.features.count == 1)
        #expect(result.lineFilters.isEmpty)
    }

    // MARK: - Line Filtering Logic

    @Test func lineFilterMatchesExactScenarioLine() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [6], feature: feature)
        #expect(matched.count == 1)
        #expect(matched[0].name == "Addition")
    }

    @Test func lineFilterMatchesStepWithinScenario() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [8], feature: feature)
        #expect(matched.count == 1)
        #expect(matched[0].name == "Addition")
    }

    @Test func lineFilterMatchesSecondScenario() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [11], feature: feature)
        #expect(matched.count == 1)
        #expect(matched[0].name == "Subtraction")
    }

    @Test func lineFilterNoMatchForFeatureLine() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [1], feature: feature)
        #expect(matched.isEmpty)
    }

    @Test func lineFilterNoMatchForBackgroundLine() throws {
        let fixtureDir = try fixturesDirectory()
        let path = (fixtureDir as NSString).appendingPathComponent("with_background.feature")
        let parser = GherkinParser()
        let feature = try parser.parseFileStoringFullPath(at: path)
        let expanded = OutlineExpander().expand(feature)
        let scenarios = expandedScenarios(from: expanded)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [3], feature: expanded)
        #expect(matched.isEmpty)
    }

    @Test func lineFilterWithMultipleAllowedLines() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [6, 11], feature: feature)
        #expect(matched.count == 2)
        let names = Set(matched.map(\.name))
        #expect(names.contains("Addition"))
        #expect(names.contains("Subtraction"))
    }

    @Test func lineFilterPastEndOfFile() throws {
        let feature = try parseBasicFeature()
        let scenarios = expandedScenarios(from: feature)

        let matched = scenariosMatchingLines(scenarios, allowedLines: [100], feature: feature)
        #expect(matched.count == 1)
        #expect(matched[0].name == "Subtraction")
    }

    // MARK: - Equatable

    @Test func featurePathEquatable() {
        let a = FeaturePath(path: "/tmp/a.feature", lines: [10], isDirectory: false)
        let b = FeaturePath(path: "/tmp/a.feature", lines: [10], isDirectory: false)
        let c = FeaturePath(path: "/tmp/a.feature", lines: [20], isDirectory: false)

        #expect(a == b)
        #expect(a != c)
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
