import Foundation

// MARK: - Parser Errors

public enum GherkinParserError: Error, LocalizedError, Equatable {
    case noFeatureFound(file: String?)
    case unexpectedKeyword(keyword: String, line: Int)
    case unterminatedDocString(startLine: Int)
    case duplicateBackground(line: Int)

    public var errorDescription: String? {
        switch self {
        case .noFeatureFound(let file):
            return "No Feature keyword found\(file.map { " in \($0)" } ?? "")"
        case .unexpectedKeyword(let keyword, let line):
            return "Unexpected keyword '\(keyword)' at line \(line)"
        case .unterminatedDocString(let startLine):
            return "Unterminated doc string starting at line \(startLine)"
        case .duplicateBackground(let line):
            return "Duplicate Background at line \(line); only one per Feature is allowed"
        }
    }
}

// MARK: - Parser

public final class GherkinParser: Sendable {

    public init() {}

    // MARK: - Public API

    /// Parse Gherkin source text into a Feature.
    public func parse(source: String, fileName: String? = nil) throws -> Feature {
        let lines = source.components(separatedBy: .newlines)
        var state = ParserState(fileName: fileName)

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            try processLine(rawLine, lineNumber: lineNumber, state: &state)
        }

        // Finalize any in-progress constructs
        try finalizeState(&state)

        guard let feature = state.feature else {
            throw GherkinParserError.noFeatureFound(file: fileName)
        }

        return feature
    }

    /// Parse a .feature file from a path.
    public func parseFile(at path: String) throws -> Feature {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        let fileName = (path as NSString).lastPathComponent
        return try parse(source: source, fileName: fileName)
    }

    /// Parse all .feature files from a bundle directory.
    public func parseBundle(bundle: Bundle, subdirectory: String? = nil) throws -> [Feature] {
        guard let urls = bundle.urls(forResourcesWithExtension: "feature", subdirectory: subdirectory) else {
            return []
        }
        return try urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).map { url in
            let source = try String(contentsOf: url, encoding: .utf8)
            return try parse(source: source, fileName: url.lastPathComponent)
        }
    }

    // MARK: - State Machine

    private enum ParseMode {
        case idle
        case inFeature
        case inBackground
        case inScenario
        case inOutline
        case inExamples
        case inDocString
    }

    private struct ParserState {
        let fileName: String?
        var mode: ParseMode = .idle

        // Feature-level
        var featureName: String?
        var featureDescription: String = ""
        var featureTags: [String] = []
        var background: Background?
        var scenarios: [ScenarioDefinition] = []

        // Pending tags (accumulated before the next construct)
        var pendingTags: [String] = []

        // Current scenario/outline
        var currentScenarioName: String = ""
        var currentScenarioTags: [String] = []
        var currentScenarioLine: Int = 0
        var currentSteps: [Step] = []

        // Current outline examples
        var currentExamples: [ExamplesTable] = []
        var currentExamplesTags: [String] = []
        var currentExamplesLine: Int = 0
        var currentExamplesRows: [[String]] = []

        // Background
        var backgroundSteps: [Step] = []
        var backgroundLine: Int = 0

        // Doc string
        var docStringLines: [String] = []
        var docStringStartLine: Int = 0
        var docStringIndent: Int = 0

        // Data table rows being accumulated for the last step
        var pendingTableRows: [[String]] = []

        // Built feature
        var feature: Feature?
    }

    private func processLine(_ rawLine: String, lineNumber: Int, state: inout ParserState) throws {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

        // Handle doc string mode
        if state.mode == .inDocString {
            if trimmed == "\"\"\"" || trimmed == "```" {
                // End doc string
                let docString = state.docStringLines.joined(separator: "\n")
                attachDocStringToLastStep(docString, state: &state)
                state.mode = state.currentScenarioName.isEmpty && state.backgroundLine > 0
                    ? .inBackground
                    : (state.currentExamplesLine > 0 ? .inExamples : (state.scenarios.last != nil || state.currentSteps.isEmpty ? .inScenario : .inScenario))
                // Restore to the appropriate mode
                restoreModeAfterDocString(&state)
            } else {
                // Strip common indent
                let lineContent: String
                if rawLine.count >= state.docStringIndent {
                    let startIndex = rawLine.index(rawLine.startIndex, offsetBy: min(state.docStringIndent, rawLine.count))
                    lineContent = String(rawLine[startIndex...])
                } else {
                    lineContent = rawLine.trimmingCharacters(in: .whitespaces)
                }
                state.docStringLines.append(lineContent)
            }
            return
        }

        // Skip empty lines and comments
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            return
        }

        // Check for tag lines
        if trimmed.hasPrefix("@") {
            let tags = parseTags(trimmed)
            state.pendingTags.append(contentsOf: tags)
            return
        }

        // Check for table rows (pipe-delimited)
        if trimmed.hasPrefix("|") {
            let cells = parseTableRow(trimmed)
            state.pendingTableRows.append(cells)
            return
        }

        // Flush pending table rows to last step if we encounter a non-table line
        flushPendingTable(&state)

        // Check for doc string delimiters
        if trimmed == "\"\"\"" || trimmed == "```" {
            state.mode = .inDocString
            state.docStringLines = []
            state.docStringStartLine = lineNumber
            // Calculate indent of the delimiter
            state.docStringIndent = rawLine.prefix(while: { $0 == " " || $0 == "\t" }).count
            return
        }

        // Keyword parsing
        if trimmed.hasPrefix("Feature:") {
            try handleFeatureKeyword(trimmed, lineNumber: lineNumber, state: &state)
        } else if trimmed.hasPrefix("Background:") {
            try handleBackgroundKeyword(lineNumber: lineNumber, state: &state)
        } else if trimmed.hasPrefix("Scenario Outline:") || trimmed.hasPrefix("Scenario Template:") {
            try handleScenarioOutlineKeyword(trimmed, lineNumber: lineNumber, state: &state)
        } else if trimmed.hasPrefix("Scenario:") {
            try handleScenarioKeyword(trimmed, lineNumber: lineNumber, state: &state)
        } else if trimmed.hasPrefix("Examples:") || trimmed.hasPrefix("Scenarios:") {
            try handleExamplesKeyword(lineNumber: lineNumber, state: &state)
        } else if let stepKeyword = parseStepKeyword(trimmed) {
            try handleStepLine(trimmed, keyword: stepKeyword, lineNumber: lineNumber, state: &state)
        } else if state.mode == .inFeature {
            // Accumulate feature description lines
            if !state.featureDescription.isEmpty {
                state.featureDescription += "\n"
            }
            state.featureDescription += trimmed
        }
    }

    // MARK: - Keyword Handlers

    private func handleFeatureKeyword(_ line: String, lineNumber: Int, state: inout ParserState) throws {
        let name = String(line.dropFirst("Feature:".count)).trimmingCharacters(in: .whitespaces)
        state.featureName = name
        state.featureTags = state.pendingTags
        state.pendingTags = []
        state.mode = .inFeature
    }

    private func handleBackgroundKeyword(lineNumber: Int, state: inout ParserState) throws {
        // Finalize any previous scenario
        finalizeCurrentScenario(&state)

        if state.background != nil {
            throw GherkinParserError.duplicateBackground(line: lineNumber)
        }

        state.backgroundSteps = []
        state.backgroundLine = lineNumber
        state.pendingTags = [] // Background doesn't support tags, discard
        state.mode = .inBackground
    }

    private func handleScenarioKeyword(_ line: String, lineNumber: Int, state: inout ParserState) throws {
        // Finalize any previous scenario/outline
        finalizeCurrentScenario(&state)

        let name = String(line.dropFirst("Scenario:".count)).trimmingCharacters(in: .whitespaces)
        state.currentScenarioName = name
        state.currentScenarioTags = state.pendingTags
        state.pendingTags = []
        state.currentScenarioLine = lineNumber
        state.currentSteps = []
        state.mode = .inScenario
    }

    private func handleScenarioOutlineKeyword(_ line: String, lineNumber: Int, state: inout ParserState) throws {
        // Finalize any previous scenario/outline
        finalizeCurrentScenario(&state)

        let prefix = line.hasPrefix("Scenario Outline:") ? "Scenario Outline:" : "Scenario Template:"
        let name = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        state.currentScenarioName = name
        state.currentScenarioTags = state.pendingTags
        state.pendingTags = []
        state.currentScenarioLine = lineNumber
        state.currentSteps = []
        state.currentExamples = []
        state.mode = .inOutline
    }

    private func handleExamplesKeyword(lineNumber: Int, state: inout ParserState) throws {
        // Flush any previous examples table
        flushCurrentExamples(&state)

        state.currentExamplesTags = state.pendingTags
        state.pendingTags = []
        state.currentExamplesLine = lineNumber
        state.currentExamplesRows = []
        state.mode = .inExamples
    }

    private func handleStepLine(_ line: String, keyword: StepKeyword, lineNumber: Int, state: inout ParserState) throws {
        let text = String(line.dropFirst(keyword.rawValue.count)).trimmingCharacters(in: .whitespaces)
        let step = Step(keyword: keyword, text: text, sourceLine: lineNumber)

        switch state.mode {
        case .inBackground:
            state.backgroundSteps.append(step)
        case .inScenario, .inOutline, .inExamples:
            state.currentSteps.append(step)
        default:
            break
        }
    }

    // MARK: - Helpers

    private func parseTags(_ line: String) -> [String] {
        line.split(separator: " ")
            .filter { $0.hasPrefix("@") }
            .map { String($0.dropFirst()) }
    }

    private func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove leading and trailing pipes, split by pipe
        let inner = trimmed.dropFirst().dropLast()
        return inner.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func parseStepKeyword(_ line: String) -> StepKeyword? {
        for keyword in [StepKeyword.given, .when, .then, .and, .but] {
            let prefix = keyword.rawValue + " "
            if line.hasPrefix(prefix) {
                return keyword
            }
        }
        return nil
    }

    private func flushPendingTable(_ state: inout ParserState) {
        guard !state.pendingTableRows.isEmpty else { return }

        if state.mode == .inExamples {
            // These rows belong to an Examples table
            state.currentExamplesRows.append(contentsOf: state.pendingTableRows)
            state.pendingTableRows = []
            return
        }

        // Attach table to the last step
        let table = DataTable(rows: state.pendingTableRows)
        state.pendingTableRows = []

        switch state.mode {
        case .inBackground:
            if var lastStep = state.backgroundSteps.last {
                state.backgroundSteps.removeLast()
                lastStep = Step(
                    keyword: lastStep.keyword,
                    text: lastStep.text,
                    dataTable: table,
                    docString: lastStep.docString,
                    sourceLine: lastStep.sourceLine
                )
                state.backgroundSteps.append(lastStep)
            }
        case .inScenario, .inOutline:
            if var lastStep = state.currentSteps.last {
                state.currentSteps.removeLast()
                lastStep = Step(
                    keyword: lastStep.keyword,
                    text: lastStep.text,
                    dataTable: table,
                    docString: lastStep.docString,
                    sourceLine: lastStep.sourceLine
                )
                state.currentSteps.append(lastStep)
            }
        default:
            break
        }
    }

    private func attachDocStringToLastStep(_ docString: String, state: inout ParserState) {
        func replaceLastStep(_ steps: inout [Step]) {
            guard var lastStep = steps.last else { return }
            steps.removeLast()
            lastStep = Step(
                keyword: lastStep.keyword,
                text: lastStep.text,
                dataTable: lastStep.dataTable,
                docString: docString,
                sourceLine: lastStep.sourceLine
            )
            steps.append(lastStep)
        }

        // Determine which step list to attach to based on the pre-docstring context
        if state.backgroundLine > 0 && state.currentScenarioName.isEmpty {
            replaceLastStep(&state.backgroundSteps)
        } else {
            replaceLastStep(&state.currentSteps)
        }
    }

    private func restoreModeAfterDocString(_ state: inout ParserState) {
        if state.currentScenarioName.isEmpty && state.backgroundLine > 0 {
            state.mode = .inBackground
        } else if !state.currentExamples.isEmpty || state.currentExamplesLine > 0 {
            state.mode = .inOutline
        } else if !state.currentScenarioName.isEmpty {
            state.mode = .inScenario
        } else {
            state.mode = .inFeature
        }
    }

    private func flushCurrentExamples(_ state: inout ParserState) {
        guard !state.currentExamplesRows.isEmpty else { return }
        let table = DataTable(rows: state.currentExamplesRows)
        let examples = ExamplesTable(
            tags: state.currentExamplesTags,
            table: table,
            sourceLine: state.currentExamplesLine
        )
        state.currentExamples.append(examples)
        state.currentExamplesRows = []
        state.currentExamplesTags = []
        state.currentExamplesLine = 0
    }

    private func finalizeCurrentScenario(_ state: inout ParserState) {
        // Flush any pending table or examples
        flushPendingTable(&state)
        flushCurrentExamples(&state)

        // Finalize background
        if state.mode == .inBackground {
            state.background = Background(
                steps: state.backgroundSteps,
                sourceLine: state.backgroundLine
            )
            state.backgroundSteps = []
            state.backgroundLine = 0
            return
        }

        guard !state.currentScenarioName.isEmpty else { return }

        switch state.mode {
        case .inScenario:
            let scenario = Scenario(
                name: state.currentScenarioName,
                tags: state.currentScenarioTags,
                steps: state.currentSteps,
                sourceLine: state.currentScenarioLine
            )
            state.scenarios.append(.scenario(scenario))

        case .inOutline, .inExamples:
            let outline = ScenarioOutline(
                name: state.currentScenarioName,
                tags: state.currentScenarioTags,
                steps: state.currentSteps,
                examples: state.currentExamples,
                sourceLine: state.currentScenarioLine
            )
            state.scenarios.append(.outline(outline))

        default:
            break
        }

        // Reset current scenario state
        state.currentScenarioName = ""
        state.currentScenarioTags = []
        state.currentScenarioLine = 0
        state.currentSteps = []
        state.currentExamples = []
    }

    private func finalizeState(_ state: inout ParserState) throws {
        if state.mode == .inDocString {
            throw GherkinParserError.unterminatedDocString(startLine: state.docStringStartLine)
        }

        // Finalize any in-progress construct
        finalizeCurrentScenario(&state)

        guard let name = state.featureName else { return }

        state.feature = Feature(
            name: name,
            description: state.featureDescription,
            tags: state.featureTags,
            background: state.background,
            scenarios: state.scenarios,
            sourceFile: state.fileName
        )
    }
}
