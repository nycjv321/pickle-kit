import Foundation

// MARK: - Step Status

/// Status of an individual step execution.
public enum StepStatus: String, Sendable {
    case passed
    case failed
    case skipped
    case undefined
}

// MARK: - Step Result

/// Result of executing a single Gherkin step, including timing and error info.
public struct StepResult: Sendable, Equatable {
    public let keyword: String
    public let text: String
    public let status: StepStatus
    public let duration: TimeInterval
    public let error: String?
    public let sourceLine: Int

    public init(
        keyword: String,
        text: String,
        status: StepStatus,
        duration: TimeInterval = 0,
        error: String? = nil,
        sourceLine: Int = 0
    ) {
        self.keyword = keyword
        self.text = text
        self.status = status
        self.duration = duration
        self.error = error
        self.sourceLine = sourceLine
    }
}
