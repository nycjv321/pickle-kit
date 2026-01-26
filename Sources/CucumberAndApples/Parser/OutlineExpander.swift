import Foundation

/// Expands `ScenarioOutline` definitions into concrete `Scenario` instances
/// by substituting `<placeholder>` tokens with values from each Examples row.
public struct OutlineExpander: Sendable {

    public init() {}

    /// Expand all outline definitions in a feature into concrete scenarios.
    /// Regular scenarios pass through unchanged.
    public func expand(_ feature: Feature) -> Feature {
        let expanded = feature.scenarios.flatMap { definition -> [ScenarioDefinition] in
            switch definition {
            case .scenario:
                return [definition]
            case .outline(let outline):
                return expandOutline(outline).map { .scenario($0) }
            }
        }

        return Feature(
            name: feature.name,
            description: feature.description,
            tags: feature.tags,
            background: feature.background,
            scenarios: expanded,
            sourceFile: feature.sourceFile
        )
    }

    /// Expand a single ScenarioOutline into concrete Scenarios.
    public func expandOutline(_ outline: ScenarioOutline) -> [Scenario] {
        var scenarios: [Scenario] = []

        for (exampleIndex, examples) in outline.examples.enumerated() {
            let headers = examples.table.headers
            let dataRows = examples.table.dataRows

            for (rowIndex, row) in dataRows.enumerated() {
                let substitutions = Dictionary(
                    uniqueKeysWithValues: zip(headers, row)
                )

                let expandedSteps = outline.steps.map { step in
                    Step(
                        keyword: step.keyword,
                        text: substitute(step.text, with: substitutions),
                        dataTable: step.dataTable.map { substituteTable($0, with: substitutions) },
                        docString: step.docString.map { substitute($0, with: substitutions) },
                        sourceLine: step.sourceLine
                    )
                }

                let name: String
                if outline.examples.count > 1 {
                    name = "\(outline.name) [Examples \(exampleIndex + 1), Row \(rowIndex + 1)]"
                } else {
                    name = "\(outline.name) [Row \(rowIndex + 1)]"
                }

                // Combine outline tags with example-level tags
                let combinedTags = outline.tags + examples.tags

                let scenario = Scenario(
                    name: name,
                    tags: combinedTags,
                    steps: expandedSteps,
                    sourceLine: outline.sourceLine
                )
                scenarios.append(scenario)
            }
        }

        return scenarios
    }

    // MARK: - Private

    private func substitute(_ text: String, with values: [String: String]) -> String {
        var result = text
        for (key, value) in values {
            result = result.replacingOccurrences(of: "<\(key)>", with: value)
        }
        return result
    }

    private func substituteTable(_ table: DataTable, with values: [String: String]) -> DataTable {
        let newRows = table.rows.map { row in
            row.map { cell in substitute(cell, with: values) }
        }
        return DataTable(rows: newRows)
    }
}
