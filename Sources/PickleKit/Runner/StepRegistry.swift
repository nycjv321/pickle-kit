import Foundation

// MARK: - Step Match

/// The result of matching a step text against a registered pattern.
public struct StepMatch: Sendable {
    /// Captured groups from the regex match.
    public let captures: [String]
    /// Data table attached to the step, if any.
    public let dataTable: DataTable?
    /// Doc string attached to the step, if any.
    public let docString: String?

    public init(captures: [String], dataTable: DataTable? = nil, docString: String? = nil) {
        self.captures = captures
        self.dataTable = dataTable
        self.docString = docString
    }
}

// MARK: - Step Handler

/// A closure that executes a matched step.
public typealias StepHandler = @Sendable (StepMatch) async throws -> Void

// MARK: - Registry Errors

public enum StepRegistryError: Error, LocalizedError, Equatable {
    case undefinedStep(text: String, keyword: String, line: Int)
    case ambiguousStep(text: String, matchCount: Int)

    public var errorDescription: String? {
        switch self {
        case .undefinedStep(let text, let keyword, let line):
            return "Undefined step at line \(line): \(keyword) \(text)"
        case .ambiguousStep(let text, let matchCount):
            return "Ambiguous step '\(text)' matches \(matchCount) definitions"
        }
    }
}

// MARK: - Step Definition

private struct StepDefinition: @unchecked Sendable {
    let pattern: String
    let regex: NSRegularExpression
    let handler: StepHandler
}

// MARK: - Step Registry

/// A registry that maps regex patterns to step handler closures.
/// Instance-based (not singleton) for testability.
public final class StepRegistry: @unchecked Sendable {

    private var definitions: [StepDefinition] = []

    public init() {}

    // MARK: - Registration

    /// Register a step definition with a regex pattern string.
    public func given(_ pattern: String, handler: @escaping StepHandler) {
        register(pattern: pattern, handler: handler)
    }

    /// Register a step definition with a regex pattern string.
    public func when(_ pattern: String, handler: @escaping StepHandler) {
        register(pattern: pattern, handler: handler)
    }

    /// Register a step definition with a regex pattern string.
    public func then(_ pattern: String, handler: @escaping StepHandler) {
        register(pattern: pattern, handler: handler)
    }

    /// Register a step definition with a regex pattern string (keyword-agnostic).
    public func step(_ pattern: String, handler: @escaping StepHandler) {
        register(pattern: pattern, handler: handler)
    }

    /// Clear all registered definitions.
    public func reset() {
        definitions = []
    }

    /// The number of registered step definitions.
    public var count: Int {
        definitions.count
    }

    // MARK: - Matching

    /// Find a matching step definition for the given step text.
    /// Returns the handler and match info, or nil if no match found.
    /// Throws if the step text matches multiple definitions (ambiguous).
    public func match(_ step: Step) throws -> (handler: StepHandler, match: StepMatch)? {
        let text = step.text
        var matches: [(StepDefinition, [String])] = []

        for definition in definitions {
            let range = NSRange(text.startIndex..., in: text)
            if let result = definition.regex.firstMatch(in: text, range: range) {
                var captures: [String] = []
                for i in 1..<result.numberOfRanges {
                    let captureRange = result.range(at: i)
                    if captureRange.location != NSNotFound,
                       let swiftRange = Range(captureRange, in: text) {
                        captures.append(String(text[swiftRange]))
                    }
                }
                matches.append((definition, captures))
            }
        }

        if matches.isEmpty {
            return nil
        }

        if matches.count > 1 {
            throw StepRegistryError.ambiguousStep(text: text, matchCount: matches.count)
        }

        let (definition, captures) = matches[0]
        let stepMatch = StepMatch(
            captures: captures,
            dataTable: step.dataTable,
            docString: step.docString
        )
        return (definition.handler, stepMatch)
    }

    // MARK: - Private

    private func register(pattern: String, handler: @escaping StepHandler) {
        // Anchor the pattern to match the full string
        let anchored = "^\(pattern)$"
        // Force try is acceptable here — invalid patterns are programmer errors
        // that should be caught during development
        let regex = try! NSRegularExpression(pattern: anchored, options: [])
        definitions.append(StepDefinition(pattern: pattern, regex: regex, handler: handler))
    }
}
