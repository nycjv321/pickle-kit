import Testing
import Foundation
@testable import PickleKit

@Suite
struct ParserTests {

    let parser = GherkinParser()

    // MARK: - Basic Parsing

    @Test func parseBasicFeature() throws {
        let feature = try loadFixture("basic")

        #expect(feature.name == "Basic arithmetic")
        #expect(feature.scenarios.count == 2)
        #expect(feature.background == nil)
    }

    @Test func parseFeatureDescription() throws {
        let feature = try loadFixture("basic")

        #expect(feature.description.contains("As a user"))
        #expect(feature.description.contains("I want to perform basic math"))
    }

    @Test func parseScenarioNames() throws {
        let feature = try loadFixture("basic")

        #expect(feature.scenarios[0].name == "Addition")
        #expect(feature.scenarios[1].name == "Subtraction")
    }

    @Test func parseSteps() throws {
        let feature = try loadFixture("basic")

        let scenario = try #require(feature.scenarios[0].asScenario)

        #expect(scenario.steps.count == 3)
        #expect(scenario.steps[0].keyword == .given)
        #expect(scenario.steps[0].text == "I have the number 5")
        #expect(scenario.steps[1].keyword == .when)
        #expect(scenario.steps[1].text == "I add 3")
        #expect(scenario.steps[2].keyword == .then)
        #expect(scenario.steps[2].text == "the result should be 8")
    }

    @Test func stepSourceLines() throws {
        let feature = try loadFixture("basic")

        let scenario = try #require(feature.scenarios[0].asScenario)

        // Lines should be > 0 (1-based)
        for step in scenario.steps {
            #expect(step.sourceLine > 0)
        }
    }

    // MARK: - Background

    @Test func parseBackground() throws {
        let feature = try loadFixture("with_background")

        #expect(feature.background != nil)
        #expect(feature.background?.steps.count == 2)
        #expect(feature.background?.steps[0].keyword == .given)
        #expect(feature.background?.steps[0].text == "I have an empty cart")
        #expect(feature.background?.steps[1].keyword == .and)
        #expect(feature.background?.steps[1].text == "I am logged in as \"testuser\"")
    }

    @Test func backgroundWithMultipleScenarios() throws {
        let feature = try loadFixture("with_background")

        #expect(feature.scenarios.count == 2)
    }

    // MARK: - Scenario Outline

    @Test func parseScenarioOutline() throws {
        let feature = try loadFixture("with_outline")

        #expect(feature.scenarios.count == 1)
        let outline = try #require(feature.scenarios[0].asOutline)

        #expect(outline.name == "Eating fruits")
        #expect(outline.steps.count == 3)
        #expect(outline.examples.count == 2)
    }

    @Test func outlineExamplesTable() throws {
        let feature = try loadFixture("with_outline")

        let outline = try #require(feature.scenarios[0].asOutline)

        let firstExamples = outline.examples[0]
        #expect(firstExamples.table.headers == ["start", "eaten", "remaining"])
        #expect(firstExamples.table.dataRows.count == 2)
        #expect(firstExamples.table.dataRows[0] == ["12", "5", "7"])
        #expect(firstExamples.table.dataRows[1] == ["20", "5", "15"])
    }

    @Test func outlineStepPlaceholders() throws {
        let feature = try loadFixture("with_outline")

        let outline = try #require(feature.scenarios[0].asOutline)

        #expect(outline.steps[0].text == "I have <start> fruits")
        #expect(outline.steps[1].text == "I eat <eaten> fruits")
    }

    // MARK: - Data Tables

    @Test func parseDataTable() throws {
        let feature = try loadFixture("with_tables")

        let scenario = try #require(feature.scenarios[0].asScenario)

        let step = scenario.steps[0]
        #expect(step.dataTable != nil)
        #expect(step.dataTable?.headers == ["name", "email", "role"])
        #expect(step.dataTable?.dataRows.count == 3)
        #expect(step.dataTable?.dataRows[0] == ["Alice", "alice@example.com", "admin"])
    }

    @Test func dataTableAsDictionaries() throws {
        let feature = try loadFixture("with_tables")

        let scenario = try #require(feature.scenarios[0].asScenario)

        let dicts = scenario.steps[0].dataTable?.asDictionaries ?? []
        #expect(dicts.count == 3)
        #expect(dicts[0]["name"] == "Alice")
        #expect(dicts[0]["role"] == "admin")
        #expect(dicts[1]["email"] == "bob@example.com")
    }

    // MARK: - Doc Strings

    @Test func parseDocString() throws {
        let feature = try loadFixture("with_docstrings")

        let scenario = try #require(feature.scenarios[0].asScenario)

        let step = scenario.steps[0]
        #expect(step.docString != nil)
        #expect(step.docString!.contains("\"status\": \"ok\""))
        #expect(step.docString!.contains("\"count\": 42"))
    }

    @Test func multiLineDocString() throws {
        let feature = try loadFixture("with_docstrings")

        let scenario = try #require(feature.scenarios[1].asScenario)

        let step = scenario.steps[0]
        #expect(step.docString != nil)
        let lines = step.docString!.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "First line")
        #expect(lines[1] == "Second line")
        #expect(lines[2] == "Third line")
    }

    // MARK: - Tags

    @Test func featureTags() throws {
        let feature = try loadFixture("with_tags")

        #expect(feature.tags == ["smoke"])
    }

    @Test func scenarioTags() throws {
        let feature = try loadFixture("with_tags")

        #expect(feature.scenarios[0].tags == ["fast"])
        #expect(feature.scenarios[1].tags == ["slow", "integration"])
        #expect(feature.scenarios[2].tags == ["wip"])
    }

    // MARK: - Comments

    @Test func commentsIgnored() throws {
        let source = """
        # This is a comment
        Feature: With comments
          # Another comment
          Scenario: Test
            Given something
            # Step comment
            Then something else
        """

        let feature = try parser.parse(source: source)
        #expect(feature.name == "With comments")
        let scenario = try #require(feature.scenarios[0].asScenario)
        #expect(scenario.steps.count == 2)
    }

    // MARK: - Error Cases

    @Test func noFeatureThrows() {
        let source = """
        Scenario: Orphan
          Given something
        """

        #expect(throws: GherkinParserError.self) {
            try parser.parse(source: source)
        }
    }

    @Test func emptySourceThrows() {
        #expect(throws: GherkinParserError.self) {
            try parser.parse(source: "")
        }
    }

    @Test func unterminatedDocStringThrows() {
        let source = """
        Feature: Bad
          Scenario: Unterminated
            Given text:
              \"""
              some content
        """

        #expect(throws: GherkinParserError.self) {
            try parser.parse(source: source)
        }
    }

    // MARK: - Source File

    @Test func sourceFilePreserved() throws {
        let feature = try parser.parse(source: "Feature: Test", fileName: "test.feature")
        #expect(feature.sourceFile == "test.feature")
    }

    // MARK: - Bundle Parsing

    @Test func parseBundleFixtures() throws {
        let features = try parser.parseBundle(
            bundle: Bundle.module,
            subdirectory: "Fixtures"
        )

        #expect(features.count == 6)
    }

    // MARK: - And/But Keywords

    @Test func andButKeywords() throws {
        let source = """
        Feature: Keywords
          Scenario: All keywords
            Given a precondition
            And another precondition
            When an action
            But not this action
            Then a result
            And another result
        """

        let feature = try parser.parse(source: source)
        let scenario = try #require(feature.scenarios[0].asScenario)

        #expect(scenario.steps.count == 6)
        #expect(scenario.steps[1].keyword == .and)
        #expect(scenario.steps[3].keyword == .but)
        #expect(scenario.steps[5].keyword == .and)
    }

    // MARK: - Helpers

    private func loadFixture(_ name: String) throws -> Feature {
        guard let url = Bundle.module.url(forResource: name, withExtension: "feature", subdirectory: "Fixtures") else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(name)"])
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        return try parser.parse(source: source, fileName: "\(name).feature")
    }
}
