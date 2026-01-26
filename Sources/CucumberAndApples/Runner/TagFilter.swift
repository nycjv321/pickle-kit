import Foundation

/// Filters scenarios by include/exclude tag sets.
public struct TagFilter: Sendable, Equatable {

    /// Tags that must be present for inclusion (any match = included).
    /// If empty, all scenarios are included by default.
    public let includeTags: Set<String>

    /// Tags that cause exclusion (any match = excluded).
    /// Exclusion takes priority over inclusion.
    public let excludeTags: Set<String>

    public init(includeTags: Set<String> = [], excludeTags: Set<String> = []) {
        self.includeTags = includeTags
        self.excludeTags = excludeTags
    }

    /// Creates a `TagFilter` from the `CUCUMBER_TAGS` and `CUCUMBER_EXCLUDE_TAGS`
    /// environment variables. Returns `nil` if neither variable is set.
    ///
    /// Values are comma-separated and whitespace-trimmed:
    /// ```
    /// CUCUMBER_TAGS=smoke,critical CUCUMBER_EXCLUDE_TAGS=wip swift test
    /// ```
    public static func fromEnvironment() -> TagFilter? {
        let env = ProcessInfo.processInfo.environment
        let rawInclude = env["CUCUMBER_TAGS"]
        let rawExclude = env["CUCUMBER_EXCLUDE_TAGS"]

        guard rawInclude != nil || rawExclude != nil else { return nil }

        let include = Self.parseTags(rawInclude)
        let exclude = Self.parseTags(rawExclude)
        return TagFilter(includeTags: include, excludeTags: exclude)
    }

    /// Returns a new filter that unions the include and exclude sets from both filters.
    public func merging(_ other: TagFilter) -> TagFilter {
        TagFilter(
            includeTags: includeTags.union(other.includeTags),
            excludeTags: excludeTags.union(other.excludeTags)
        )
    }

    /// Determine whether a scenario with the given tags should be included.
    public func shouldInclude(tags: [String]) -> Bool {
        let tagSet = Set(tags)

        // Exclusion takes priority
        if !excludeTags.isEmpty && !excludeTags.isDisjoint(with: tagSet) {
            return false
        }

        // If no include filter, include everything not excluded
        if includeTags.isEmpty {
            return true
        }

        // Must match at least one include tag
        return !includeTags.isDisjoint(with: tagSet)
    }

    // MARK: - Private

    private static func parseTags(_ value: String?) -> Set<String> {
        guard let value = value else { return [] }
        let tags = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(tags.filter { !$0.isEmpty })
    }
}
