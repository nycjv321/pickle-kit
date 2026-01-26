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
}
