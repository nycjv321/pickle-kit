import XCTest
@testable import CucumberAndApples

final class TagFilterTests: XCTestCase {

    // MARK: - Empty Filters

    func testEmptyFilterIncludesAll() {
        let filter = TagFilter()

        XCTAssertTrue(filter.shouldInclude(tags: []))
        XCTAssertTrue(filter.shouldInclude(tags: ["anything"]))
        XCTAssertTrue(filter.shouldInclude(tags: ["smoke", "fast"]))
    }

    // MARK: - Include Tags

    func testIncludeTagsMatchAny() {
        let filter = TagFilter(includeTags: ["smoke", "critical"])

        XCTAssertTrue(filter.shouldInclude(tags: ["smoke"]))
        XCTAssertTrue(filter.shouldInclude(tags: ["critical"]))
        XCTAssertTrue(filter.shouldInclude(tags: ["smoke", "fast"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["slow"]))
        XCTAssertFalse(filter.shouldInclude(tags: []))
    }

    // MARK: - Exclude Tags

    func testExcludeTagsReject() {
        let filter = TagFilter(excludeTags: ["wip", "skip"])

        XCTAssertTrue(filter.shouldInclude(tags: []))
        XCTAssertTrue(filter.shouldInclude(tags: ["smoke"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["wip"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["skip"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["smoke", "wip"]))
    }

    // MARK: - Combined Include + Exclude

    func testExcludeTakesPriority() {
        let filter = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])

        XCTAssertTrue(filter.shouldInclude(tags: ["smoke"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["smoke", "wip"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["wip"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["fast"])) // Not in include set
    }

    // MARK: - Edge Cases

    func testSingleIncludeTag() {
        let filter = TagFilter(includeTags: ["regression"])

        XCTAssertTrue(filter.shouldInclude(tags: ["regression"]))
        XCTAssertTrue(filter.shouldInclude(tags: ["regression", "slow"]))
        XCTAssertFalse(filter.shouldInclude(tags: ["smoke"]))
    }

    func testSingleExcludeTag() {
        let filter = TagFilter(excludeTags: ["manual"])

        XCTAssertTrue(filter.shouldInclude(tags: ["smoke"]))
        XCTAssertTrue(filter.shouldInclude(tags: []))
        XCTAssertFalse(filter.shouldInclude(tags: ["manual"]))
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let b = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let c = TagFilter(includeTags: ["fast"], excludeTags: ["wip"])

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - fromEnvironment

    override func setUp() {
        super.setUp()
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
    }

    override func tearDown() {
        unsetenv("CUCUMBER_TAGS")
        unsetenv("CUCUMBER_EXCLUDE_TAGS")
        super.tearDown()
    }

    func testFromEnvironmentWithIncludeTags() {
        setenv("CUCUMBER_TAGS", "smoke,critical", 1)

        let filter = TagFilter.fromEnvironment()
        XCTAssertNotNil(filter)
        XCTAssertEqual(filter?.includeTags, ["smoke", "critical"])
        XCTAssertEqual(filter?.excludeTags, [])
    }

    func testFromEnvironmentWithExcludeTags() {
        setenv("CUCUMBER_EXCLUDE_TAGS", "wip,manual", 1)

        let filter = TagFilter.fromEnvironment()
        XCTAssertNotNil(filter)
        XCTAssertEqual(filter?.includeTags, [])
        XCTAssertEqual(filter?.excludeTags, ["wip", "manual"])
    }

    func testFromEnvironmentWithBoth() {
        setenv("CUCUMBER_TAGS", "smoke,fast", 1)
        setenv("CUCUMBER_EXCLUDE_TAGS", "wip,slow", 1)

        let filter = TagFilter.fromEnvironment()
        XCTAssertNotNil(filter)
        XCTAssertEqual(filter?.includeTags, ["smoke", "fast"])
        XCTAssertEqual(filter?.excludeTags, ["wip", "slow"])
    }

    func testFromEnvironmentReturnsNilWhenUnset() {
        let filter = TagFilter.fromEnvironment()
        XCTAssertNil(filter)
    }

    func testFromEnvironmentTrimsWhitespace() {
        setenv("CUCUMBER_TAGS", " smoke , fast ", 1)

        let filter = TagFilter.fromEnvironment()
        XCTAssertNotNil(filter)
        XCTAssertEqual(filter?.includeTags, ["smoke", "fast"])
    }

    // MARK: - merging

    func testMergingCombinesSets() {
        let a = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let b = TagFilter(includeTags: ["fast"], excludeTags: ["manual"])

        let merged = a.merging(b)
        XCTAssertEqual(merged.includeTags, ["smoke", "fast"])
        XCTAssertEqual(merged.excludeTags, ["wip", "manual"])
    }

    func testMergingWithEmptyFilter() {
        let original = TagFilter(includeTags: ["smoke"], excludeTags: ["wip"])
        let empty = TagFilter()

        let merged = original.merging(empty)
        XCTAssertEqual(merged, original)
    }
}
