import XCTest
@testable import PickleKit

final class ParserTests: XCTestCase {

    let parser = GherkinParser()

    // MARK: - Basic Parsing

    func testParseBasicFeature() throws {
        let feature = try loadFixture("basic")

        XCTAssertEqual(feature.name, "Basic arithmetic")
        XCTAssertEqual(feature.scenarios.count, 2)
        XCTAssertNil(feature.background)
    }

    func testParseFeatureDescription() throws {
        let feature = try loadFixture("basic")

        XCTAssertTrue(feature.description.contains("As a user"))
        XCTAssertTrue(feature.description.contains("I want to perform basic math"))
    }

    func testParseScenarioNames() throws {
        let feature = try loadFixture("basic")

        XCTAssertEqual(feature.scenarios[0].name, "Addition")
        XCTAssertEqual(feature.scenarios[1].name, "Subtraction")
    }

    func testParseSteps() throws {
        let feature = try loadFixture("basic")

        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        XCTAssertEqual(scenario.steps.count, 3)
        XCTAssertEqual(scenario.steps[0].keyword, .given)
        XCTAssertEqual(scenario.steps[0].text, "I have the number 5")
        XCTAssertEqual(scenario.steps[1].keyword, .when)
        XCTAssertEqual(scenario.steps[1].text, "I add 3")
        XCTAssertEqual(scenario.steps[2].keyword, .then)
        XCTAssertEqual(scenario.steps[2].text, "the result should be 8")
    }

    func testStepSourceLines() throws {
        let feature = try loadFixture("basic")

        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        // Lines should be > 0 (1-based)
        for step in scenario.steps {
            XCTAssertGreaterThan(step.sourceLine, 0)
        }
    }

    // MARK: - Background

    func testParseBackground() throws {
        let feature = try loadFixture("with_background")

        XCTAssertNotNil(feature.background)
        XCTAssertEqual(feature.background?.steps.count, 2)
        XCTAssertEqual(feature.background?.steps[0].keyword, .given)
        XCTAssertEqual(feature.background?.steps[0].text, "I have an empty cart")
        XCTAssertEqual(feature.background?.steps[1].keyword, .and)
        XCTAssertEqual(feature.background?.steps[1].text, "I am logged in as \"testuser\"")
    }

    func testBackgroundWithMultipleScenarios() throws {
        let feature = try loadFixture("with_background")

        XCTAssertEqual(feature.scenarios.count, 2)
    }

    // MARK: - Scenario Outline

    func testParseScenarioOutline() throws {
        let feature = try loadFixture("with_outline")

        XCTAssertEqual(feature.scenarios.count, 1)
        guard case .outline(let outline) = feature.scenarios[0] else {
            XCTFail("Expected outline"); return
        }

        XCTAssertEqual(outline.name, "Eating fruits")
        XCTAssertEqual(outline.steps.count, 3)
        XCTAssertEqual(outline.examples.count, 2)
    }

    func testOutlineExamplesTable() throws {
        let feature = try loadFixture("with_outline")

        guard case .outline(let outline) = feature.scenarios[0] else {
            XCTFail("Expected outline"); return
        }

        let firstExamples = outline.examples[0]
        XCTAssertEqual(firstExamples.table.headers, ["start", "eaten", "remaining"])
        XCTAssertEqual(firstExamples.table.dataRows.count, 2)
        XCTAssertEqual(firstExamples.table.dataRows[0], ["12", "5", "7"])
        XCTAssertEqual(firstExamples.table.dataRows[1], ["20", "5", "15"])
    }

    func testOutlineStepPlaceholders() throws {
        let feature = try loadFixture("with_outline")

        guard case .outline(let outline) = feature.scenarios[0] else {
            XCTFail("Expected outline"); return
        }

        XCTAssertEqual(outline.steps[0].text, "I have <start> fruits")
        XCTAssertEqual(outline.steps[1].text, "I eat <eaten> fruits")
    }

    // MARK: - Data Tables

    func testParseDataTable() throws {
        let feature = try loadFixture("with_tables")

        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        let step = scenario.steps[0]
        XCTAssertNotNil(step.dataTable)
        XCTAssertEqual(step.dataTable?.headers, ["name", "email", "role"])
        XCTAssertEqual(step.dataTable?.dataRows.count, 3)
        XCTAssertEqual(step.dataTable?.dataRows[0], ["Alice", "alice@example.com", "admin"])
    }

    func testDataTableAsDictionaries() throws {
        let feature = try loadFixture("with_tables")

        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        let dicts = scenario.steps[0].dataTable?.asDictionaries ?? []
        XCTAssertEqual(dicts.count, 3)
        XCTAssertEqual(dicts[0]["name"], "Alice")
        XCTAssertEqual(dicts[0]["role"], "admin")
        XCTAssertEqual(dicts[1]["email"], "bob@example.com")
    }

    // MARK: - Doc Strings

    func testParseDocString() throws {
        let feature = try loadFixture("with_docstrings")

        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        let step = scenario.steps[0]
        XCTAssertNotNil(step.docString)
        XCTAssertTrue(step.docString!.contains("\"status\": \"ok\""))
        XCTAssertTrue(step.docString!.contains("\"count\": 42"))
    }

    func testMultiLineDocString() throws {
        let feature = try loadFixture("with_docstrings")

        guard case .scenario(let scenario) = feature.scenarios[1] else {
            XCTFail("Expected scenario"); return
        }

        let step = scenario.steps[0]
        XCTAssertNotNil(step.docString)
        let lines = step.docString!.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0], "First line")
        XCTAssertEqual(lines[1], "Second line")
        XCTAssertEqual(lines[2], "Third line")
    }

    // MARK: - Tags

    func testFeatureTags() throws {
        let feature = try loadFixture("with_tags")

        XCTAssertEqual(feature.tags, ["smoke"])
    }

    func testScenarioTags() throws {
        let feature = try loadFixture("with_tags")

        XCTAssertEqual(feature.scenarios[0].tags, ["fast"])
        XCTAssertEqual(feature.scenarios[1].tags, ["slow", "integration"])
        XCTAssertEqual(feature.scenarios[2].tags, ["wip"])
    }

    // MARK: - Comments

    func testCommentsIgnored() throws {
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
        XCTAssertEqual(feature.name, "With comments")
        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }
        XCTAssertEqual(scenario.steps.count, 2)
    }

    // MARK: - Error Cases

    func testNoFeatureThrows() {
        let source = """
        Scenario: Orphan
          Given something
        """

        XCTAssertThrowsError(try parser.parse(source: source)) { error in
            XCTAssertTrue(error is GherkinParserError)
        }
    }

    func testEmptySourceThrows() {
        XCTAssertThrowsError(try parser.parse(source: "")) { error in
            guard let parserError = error as? GherkinParserError else {
                XCTFail("Expected GherkinParserError"); return
            }
            if case .noFeatureFound = parserError {} else {
                XCTFail("Expected noFeatureFound error")
            }
        }
    }

    func testUnterminatedDocStringThrows() {
        let source = """
        Feature: Bad
          Scenario: Unterminated
            Given text:
              \"""
              some content
        """

        XCTAssertThrowsError(try parser.parse(source: source)) { error in
            guard let parserError = error as? GherkinParserError else {
                XCTFail("Expected GherkinParserError"); return
            }
            if case .unterminatedDocString = parserError {} else {
                XCTFail("Expected unterminatedDocString error")
            }
        }
    }

    // MARK: - Source File

    func testSourceFilePreserved() throws {
        let feature = try parser.parse(source: "Feature: Test", fileName: "test.feature")
        XCTAssertEqual(feature.sourceFile, "test.feature")
    }

    // MARK: - Bundle Parsing

    func testParseBundleFixtures() throws {
        let features = try parser.parseBundle(
            bundle: Bundle.module,
            subdirectory: "Fixtures"
        )

        XCTAssertEqual(features.count, 6)
    }

    // MARK: - And/But Keywords

    func testAndButKeywords() throws {
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
        guard case .scenario(let scenario) = feature.scenarios[0] else {
            XCTFail("Expected scenario"); return
        }

        XCTAssertEqual(scenario.steps.count, 6)
        XCTAssertEqual(scenario.steps[1].keyword, .and)
        XCTAssertEqual(scenario.steps[3].keyword, .but)
        XCTAssertEqual(scenario.steps[5].keyword, .and)
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
