import Foundation

/// A parsed path specification for loading feature files.
///
/// Supports individual files, directories, and `file:line` syntax for targeting
/// specific scenarios, matching Ruby Cucumber's path conventions.
///
/// ```bash
/// # Equivalent to Ruby Cucumber's positional args:
/// CUCUMBER_FEATURES="features/login.feature features/signup.feature:10" swift test
/// ```
///
/// Paths containing spaces are not supported via the environment variable.
/// Use the `featurePaths` class property on `GherkinTestCase` instead.
public struct FeaturePath: Sendable, Equatable {
    /// Resolved absolute filesystem path.
    public let path: String

    /// Line numbers for scenario targeting. Empty means all scenarios.
    public let lines: [Int]

    /// Whether this path refers to a directory of feature files.
    public let isDirectory: Bool

    public init(path: String, lines: [Int] = [], isDirectory: Bool = false) {
        self.path = path
        self.lines = lines
        self.isDirectory = isDirectory
    }

    // MARK: - Parsing

    /// Parse a single path specification like `login.feature:10:25` or `features/`.
    ///
    /// - Parameters:
    ///   - raw: The raw path string, optionally with `:line` suffixes.
    ///   - relativeTo: Base directory for resolving relative paths.
    ///     Defaults to `FileManager.default.currentDirectoryPath`.
    /// - Returns: A parsed `FeaturePath`, or `nil` if the input is empty.
    public static func parse(_ raw: String, relativeTo base: String? = nil) -> FeaturePath? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Split on ":" to extract path and optional line numbers.
        // Line numbers are trailing integer-only components.
        let components = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        var pathPart = components[0]
        var lines: [Int] = []

        // Parse trailing components as line numbers (integers only).
        for i in 1..<components.count {
            if let line = Int(components[i]), line > 0 {
                lines.append(line)
            } else {
                // Non-integer component: part of the path (e.g., not expected, but be safe)
                pathPart += ":" + components[i]
            }
        }

        // Resolve relative paths
        let resolvedPath: String
        if (pathPart as NSString).isAbsolutePath {
            resolvedPath = pathPart
        } else {
            let baseDir = base ?? FileManager.default.currentDirectoryPath
            resolvedPath = (baseDir as NSString).appendingPathComponent(pathPart)
        }

        // Standardize the path (resolve .., . etc.)
        let standardized = (resolvedPath as NSString).standardizingPath

        // Detect directory: trailing "/" in original or filesystem check
        let isDir: Bool
        if pathPart.hasSuffix("/") {
            isDir = true
        } else {
            var isDirObjC: ObjCBool = false
            if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirObjC) {
                isDir = isDirObjC.boolValue
            } else {
                isDir = false
            }
        }

        return FeaturePath(path: standardized, lines: lines, isDirectory: isDir)
    }

    /// Parse a space-separated list of path specifications.
    ///
    /// - Parameters:
    ///   - value: Space-separated path specs (e.g., `"login.feature:10 features/"`).
    ///   - relativeTo: Base directory for resolving relative paths.
    /// - Returns: Array of parsed `FeaturePath` values.
    public static func parseList(_ value: String, relativeTo base: String? = nil) -> [FeaturePath] {
        value.split(separator: " ", omittingEmptySubsequences: true)
            .compactMap { parse(String($0), relativeTo: base) }
    }

    /// Read feature paths from the `CUCUMBER_FEATURES` environment variable.
    ///
    /// - Returns: Parsed paths, or `nil` if the variable is unset or empty.
    public static func fromEnvironment() -> [FeaturePath]? {
        guard let value = ProcessInfo.processInfo.environment["CUCUMBER_FEATURES"],
              !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        let paths = parseList(value)
        return paths.isEmpty ? nil : paths
    }
}
