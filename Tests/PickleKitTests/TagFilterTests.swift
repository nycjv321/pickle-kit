import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@testable import PickleKit

@Suite(.serialized)
struct TagFilterTests {

    // MARK: - Empty Filters

    @Test func emptyFilterIncludesAll() {
        let filter = TagFilter()

        #expect(filter.shouldInclude(tags: []))
        #expect(filter.shouldInclude(tags: ["anything"]))
        #expect(filter.shouldInclude(tags: ["smoke", "fast"]))
    }

    // MARK: - Include Tags

    @Test func includeTagsMatchAny() {
        let filter = TagFilter(includeTags: ["smoke", "critical"])

        #expect(filter.shouldInclude(tags: ["smoke"]))
        #expect(filter.shouldInclude(tags: ["critical"]))
        #expect(filter.shouldInclude(tags: ["smoke", "fast"]))
        #expect(!filter.shouldInclude(tags: ["slow"]))
        #expect(!filter.shouldInclude(tags: []))
    }

    // MARK: - Exclude Tags

    @Test func excludeTagsReject() {
        let filter = TagFilter(excludeTags: ["wip", "skip"])

        #expect(filter.shouldInclude(tags: []))
        #expect(filter.shouldInclude(tags: ["smoke"]))
        #expect(!filter.shouldInclude(tags: ["wip"]))
        #expect(!filter.shouldInclude(tags: ["skip"]))
        #expect(!filter.shouldInclude(tags: ["smoke", "wip"]))
    }

    // MARK: - Combined Include + Exclude

    @Test func excludeTakesPriority() {
        let filter = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])

        #expect(filter.shouldInclude(tags: ["smoke"]))
        #expect(!filter.shouldInclude(tags: ["smoke", "wip"]))
        #expect(!filter.shouldInclude(tags: ["wip"]))
        #expect(!filter.shouldInclude(tags: ["fast"])) // Not in include set
    }

    // MARK: - Edge Cases

    @Test func singleIncludeTag() {
        let filter = TagFilter(includeTags: ["regression"])

        #expect(filter.shouldInclude(tags: ["regression"]))
        #expect(filter.shouldInclude(tags: ["regression", "slow"]))
        #expect(!filter.shouldInclude(tags: ["smoke"]))
    }

    @Test func singleExcludeTag() {
        let filter = TagFilter(excludeTags: ["manual"])

        #expect(filter.shouldInclude(tags: ["smoke"]))
        #expect(filter.shouldInclude(tags: []))
        #expect(!filter.shouldInclude(tags: ["manual"]))
    }

    // MARK: - Equatable

    @Test func equatable() {
        let a = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let b = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let c = TagFilter(includeTags: ["fast"], excludeTags: ["wip"])

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - fromEnvironment

    @Test func fromEnvironmentWithIncludeTags() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        defer { unsetenv("CUCUMBER_TAGS"); unsetenv("CUCUMBER_EXCLUDE_TAGS") }

        setenv("CUCUMBER_TAGS", "smoke,critical", 1)

        let filter = TagFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeTags == ["smoke", "critical"])
        #expect(filter?.excludeTags == [])
    }

    @Test func fromEnvironmentWithExcludeTags() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        defer { unsetenv("CUCUMBER_TAGS"); unsetenv("CUCUMBER_EXCLUDE_TAGS") }

        setenv("CUCUMBER_EXCLUDE_TAGS", "wip,manual", 1)

        let filter = TagFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeTags == [])
        #expect(filter?.excludeTags == ["wip", "manual"])
    }

    @Test func fromEnvironmentWithBoth() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        defer { unsetenv("CUCUMBER_TAGS"); unsetenv("CUCUMBER_EXCLUDE_TAGS") }

        setenv("CUCUMBER_TAGS", "smoke,fast", 1)
        setenv("CUCUMBER_EXCLUDE_TAGS", "wip,slow", 1)

        let filter = TagFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeTags == ["smoke", "fast"])
        #expect(filter?.excludeTags == ["wip", "slow"])
    }

    @Test func fromEnvironmentReturnsNilWhenUnset() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        defer { unsetenv("CUCUMBER_TAGS"); unsetenv("CUCUMBER_EXCLUDE_TAGS") }

        let filter = TagFilter.fromEnvironment()
        #expect(filter == nil)
    }

    @Test func fromEnvironmentTrimsWhitespace() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        defer { unsetenv("CUCUMBER_TAGS"); unsetenv("CUCUMBER_EXCLUDE_TAGS") }

        setenv("CUCUMBER_TAGS", " smoke , fast ", 1)

        let filter = TagFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeTags == ["smoke", "fast"])
    }

    // MARK: - merging

    @Test func mergingCombinesSets() {
        let a = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let b = TagFilter(includeTags: ["fast"], excludeTags: ["manual"])

        let merged = a.merging(b)
        #expect(merged.includeTags == ["smoke", "fast"])
        #expect(merged.excludeTags == ["wip", "manual"])
    }

    @Test func mergingWithEmptyFilter() {
        let original = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let empty = TagFilter()

        let merged = original.merging(empty)
        #expect(merged == original)
    }
}
