import XCTest
@testable import PickleKit

final class StepRegistryTests: XCTestCase {

    var registry: StepRegistry!

    override func setUp() {
        super.setUp()
        registry = StepRegistry()
    }

    // MARK: - Registration

    func testRegisterAndCount() {
        registry.given("something") { _ in }
        registry.when("action") { _ in }
        registry.then("result") { _ in }

        XCTAssertEqual(registry.count, 3)
    }

    func testReset() {
        registry.given("a") { _ in }
        registry.when("b") { _ in }
        XCTAssertEqual(registry.count, 2)

        registry.reset()
        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Matching

    func testExactMatch() throws {
        var matched = false
        registry.given("I have a cat") { _ in matched = true }

        let step = Step(keyword: .given, text: "I have a cat")
        let result = try registry.match(step)

        XCTAssertNotNil(result)
    }

    func testNoMatch() throws {
        registry.given("I have a cat") { _ in }

        let step = Step(keyword: .given, text: "I have a dog")
        let result = try registry.match(step)

        XCTAssertNil(result)
    }

    func testRegexCaptures() throws {
        var captured: [String] = []
        registry.given("I have (\\d+) (\\w+)") { match in
            captured = match.captures
        }

        let step = Step(keyword: .given, text: "I have 42 apples")
        let result = try registry.match(step)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.match.captures, ["42", "apples"])
    }

    func testQuotedStringCapture() throws {
        registry.given("my name is \"([^\"]*)\"") { _ in }

        let step = Step(keyword: .given, text: "my name is \"Alice\"")
        let result = try registry.match(step)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.match.captures, ["Alice"])
    }

    // MARK: - Keyword Agnostic

    func testStepMethodMatchesAnyKeyword() throws {
        registry.step("anything goes") { _ in }

        let givenStep = Step(keyword: .given, text: "anything goes")
        let whenStep = Step(keyword: .when, text: "anything goes")

        XCTAssertNotNil(try registry.match(givenStep))
        XCTAssertNotNil(try registry.match(whenStep))
    }

    // MARK: - Ambiguous Steps

    func testAmbiguousStepThrows() {
        registry.given("I have .*") { _ in }
        registry.given("I have (\\d+) items") { _ in }

        let step = Step(keyword: .given, text: "I have 5 items")

        XCTAssertThrowsError(try registry.match(step)) { error in
            guard let regError = error as? StepRegistryError,
                  case .ambiguousStep(_, let count) = regError else {
                XCTFail("Expected ambiguousStep error"); return
            }
            XCTAssertEqual(count, 2)
        }
    }

    // MARK: - Data Table Passthrough

    func testDataTablePassedToMatch() throws {
        registry.given("users exist:") { _ in }

        let table = DataTable(rows: [["name"], ["Alice"]])
        let step = Step(keyword: .given, text: "users exist:", dataTable: table)
        let result = try registry.match(step)

        XCTAssertNotNil(result?.match.dataTable)
        XCTAssertEqual(result?.match.dataTable?.rows.count, 2)
    }

    // MARK: - Doc String Passthrough

    func testDocStringPassedToMatch() throws {
        registry.given("the content is:") { _ in }

        let step = Step(keyword: .given, text: "the content is:", docString: "hello world")
        let result = try registry.match(step)

        XCTAssertEqual(result?.match.docString, "hello world")
    }

    // MARK: - Handler Execution

    func testHandlerExecutes() async throws {
        var executed = false
        registry.given("I do something") { _ in
            executed = true
        }

        let step = Step(keyword: .given, text: "I do something")
        let result = try registry.match(step)
        try await result?.handler(result!.match)

        XCTAssertTrue(executed)
    }

    func testHandlerReceivesCaptures() async throws {
        var receivedCaptures: [String] = []
        registry.when("I add (\\d+) and (\\d+)") { match in
            receivedCaptures = match.captures
        }

        let step = Step(keyword: .when, text: "I add 3 and 7")
        let result = try registry.match(step)
        try await result?.handler(result!.match)

        XCTAssertEqual(receivedCaptures, ["3", "7"])
    }

    // MARK: - Anchoring

    func testPatternIsAnchored() throws {
        registry.given("exact") { _ in }

        // Should not match partial strings
        let step = Step(keyword: .given, text: "not exact match")
        XCTAssertNil(try registry.match(step))
    }

    // MARK: - Invalid Patterns

    func testInvalidPatternDoesNotCrash() {
        registry.given("I have (unclosed") { _ in }
        XCTAssertEqual(registry.count, 0)
    }

    func testInvalidPatternRecordsError() {
        registry.given("I have (unclosed") { _ in }
        XCTAssertEqual(registry.registrationErrors.count, 1)
        if case .invalidPattern(let pattern, _) = registry.registrationErrors.first {
            XCTAssertEqual(pattern, "I have (unclosed")
        } else {
            XCTFail("Expected invalidPattern error")
        }
    }

    func testInvalidPatternErrorDescription() {
        registry.given("bad[") { _ in }
        let description = registry.registrationErrors.first?.localizedDescription ?? ""
        XCTAssertTrue(description.contains("bad["), "Error description should contain the pattern")
        XCTAssertTrue(description.contains("Invalid step pattern"), "Error description should indicate invalid pattern")
    }

    func testValidAndInvalidPatternsMixed() {
        registry.given("valid pattern") { _ in }
        registry.given("invalid (unclosed") { _ in }
        XCTAssertEqual(registry.count, 1)
        XCTAssertEqual(registry.registrationErrors.count, 1)
    }

    func testResetClearsRegistrationErrors() {
        registry.given("I have (unclosed") { _ in }
        XCTAssertEqual(registry.registrationErrors.count, 1)
        registry.reset()
        XCTAssertTrue(registry.registrationErrors.isEmpty)
    }
}
