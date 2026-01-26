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
}
