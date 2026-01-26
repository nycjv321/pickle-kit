import XCTest
@testable import PickleKit

final class OutlineExpanderTests: XCTestCase {

    let expander = OutlineExpander()

    // MARK: - Basic Expansion

    func testExpandSingleExamplesTable() {
        let outline = ScenarioOutline(
            name: "Eating",
            steps: [
                Step(keyword: .given, text: "I have <start> items"),
                Step(keyword: .when, text: "I remove <count>"),
                Step(keyword: .then, text: "I have <remaining>"),
            ],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [
                        ["start", "count", "remaining"],
                        ["10", "3", "7"],
                        ["5", "2", "3"],
                    ])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)

        XCTAssertEqual(scenarios.count, 2)
        XCTAssertEqual(scenarios[0].steps[0].text, "I have 10 items")
        XCTAssertEqual(scenarios[0].steps[1].text, "I remove 3")
        XCTAssertEqual(scenarios[0].steps[2].text, "I have 7")
        XCTAssertEqual(scenarios[1].steps[0].text, "I have 5 items")
    }

    // MARK: - Naming

    func testSingleExamplesTableNaming() {
        let outline = ScenarioOutline(
            name: "Login",
            steps: [Step(keyword: .given, text: "user <name>")],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [
                        ["name"],
                        ["Alice"],
                        ["Bob"],
                    ])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)

        XCTAssertEqual(scenarios[0].name, "Login [Row 1]")
        XCTAssertEqual(scenarios[1].name, "Login [Row 2]")
    }

    func testMultipleExamplesTablesNaming() {
        let outline = ScenarioOutline(
            name: "Access",
            steps: [Step(keyword: .given, text: "role <role>")],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [
                        ["role"],
                        ["admin"],
                    ])
                ),
                ExamplesTable(
                    table: DataTable(rows: [
                        ["role"],
                        ["user"],
                        ["guest"],
                    ])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)

        XCTAssertEqual(scenarios.count, 3)
        XCTAssertEqual(scenarios[0].name, "Access [Examples 1, Row 1]")
        XCTAssertEqual(scenarios[1].name, "Access [Examples 2, Row 1]")
        XCTAssertEqual(scenarios[2].name, "Access [Examples 2, Row 2]")
    }

    // MARK: - Tag Combination

    func testOutlineTagsCombinedWithExamplesTags() {
        let outline = ScenarioOutline(
            name: "Tagged",
            tags: ["smoke"],
            steps: [Step(keyword: .given, text: "<x>")],
            examples: [
                ExamplesTable(
                    tags: ["fast"],
                    table: DataTable(rows: [["x"], ["1"]])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)

        XCTAssertEqual(scenarios[0].tags, ["smoke", "fast"])
    }

    // MARK: - Feature-level Expansion

    func testExpandFeaturePassesThroughRegularScenarios() {
        let feature = Feature(
            name: "Mixed",
            scenarios: [
                .scenario(Scenario(name: "Regular", steps: [
                    Step(keyword: .given, text: "something"),
                ])),
                .outline(ScenarioOutline(
                    name: "Parameterized",
                    steps: [Step(keyword: .given, text: "value <v>")],
                    examples: [
                        ExamplesTable(
                            table: DataTable(rows: [["v"], ["1"], ["2"]])
                        ),
                    ]
                )),
            ]
        )

        let expanded = expander.expand(feature)

        XCTAssertEqual(expanded.scenarios.count, 3)

        // First should be the regular scenario unchanged
        if case .scenario(let s) = expanded.scenarios[0] {
            XCTAssertEqual(s.name, "Regular")
        } else {
            XCTFail("Expected scenario")
        }

        // Next two should be expanded from outline
        if case .scenario(let s) = expanded.scenarios[1] {
            XCTAssertEqual(s.steps[0].text, "value 1")
        } else {
            XCTFail("Expected scenario")
        }
    }

    // MARK: - Doc String Substitution

    func testDocStringPlaceholderSubstitution() {
        let outline = ScenarioOutline(
            name: "API",
            steps: [
                Step(keyword: .given, text: "response", docString: "{\"name\": \"<name>\"}"),
            ],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [["name"], ["Alice"]])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)
        XCTAssertEqual(scenarios[0].steps[0].docString, "{\"name\": \"Alice\"}")
    }

    // MARK: - Data Table Substitution

    func testDataTablePlaceholderSubstitution() {
        let outline = ScenarioOutline(
            name: "Table",
            steps: [
                Step(
                    keyword: .given,
                    text: "users",
                    dataTable: DataTable(rows: [
                        ["name", "role"],
                        ["<user>", "<role>"],
                    ])
                ),
            ],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [
                        ["user", "role"],
                        ["Alice", "admin"],
                    ])
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)
        let table = scenarios[0].steps[0].dataTable!
        XCTAssertEqual(table.rows[1], ["Alice", "admin"])
    }

    // MARK: - Empty Examples

    func testEmptyExamplesProducesNoScenarios() {
        let outline = ScenarioOutline(
            name: "Empty",
            steps: [Step(keyword: .given, text: "<x>")],
            examples: [
                ExamplesTable(
                    table: DataTable(rows: [["x"]]) // Headers only, no data rows
                ),
            ]
        )

        let scenarios = expander.expandOutline(outline)
        XCTAssertTrue(scenarios.isEmpty)
    }
}
