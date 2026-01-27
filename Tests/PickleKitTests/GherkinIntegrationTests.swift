import XCTest
import PickleKit

/// Integration test that runs fixture .feature files through GherkinTestCase.
/// This exercises the full pipeline: parsing → outline expansion → dynamic test
/// generation → step execution → report collection.
///
/// Also enables HTML report generation via `PICKLE_REPORT=1 swift test`.
final class GherkinIntegrationTests: GherkinTestCase {

    override class var featureBundle: Bundle { Bundle.module }
    override class var featureSubdirectory: String? { "Fixtures" }

    // State shared across steps within a single scenario
    nonisolated(unsafe) static var number: Int = 0
    nonisolated(unsafe) static var cart: [String] = []
    nonisolated(unsafe) static var loggedInUser: String? = nil
    nonisolated(unsafe) static var fruits: Int = 0
    nonisolated(unsafe) static var users: [[String: String]] = []
    nonisolated(unsafe) static var searchResults: Int = 0
    nonisolated(unsafe) static var apiResponse: String? = nil
    nonisolated(unsafe) static var document: String? = nil

    override func setUp() {
        super.setUp()
        Self.number = 0
        Self.cart = []
        Self.loggedInUser = nil
        Self.fruits = 0
        Self.users = []
        Self.searchResults = 0
        Self.apiResponse = nil
        Self.document = nil
    }

    override func registerStepDefinitions() {

        // MARK: - Basic arithmetic (basic.feature)

        given("I have the number (\\d+)") { match in
            Self.number = Int(match.captures[0])!
        }

        when("I add (\\d+)") { match in
            Self.number += Int(match.captures[0])!
        }

        when("I subtract (\\d+)") { match in
            Self.number -= Int(match.captures[0])!
        }

        then("the result should be (\\d+)") { match in
            let expected = Int(match.captures[0])!
            XCTAssertEqual(Self.number, expected)
        }

        // MARK: - Shopping cart (with_background.feature)

        given("I have an empty cart") { _ in
            Self.cart = []
        }

        given("I am logged in as \"([^\"]*)\"") { match in
            Self.loggedInUser = match.captures[0]
        }

        when("I add \"([^\"]*)\" to the cart") { match in
            Self.cart.append(match.captures[0])
        }

        then("the cart should contain (\\d+) items?") { match in
            let expected = Int(match.captures[0])!
            XCTAssertEqual(Self.cart.count, expected)
        }

        // MARK: - Tagged scenarios (with_tags.feature)

        given("I have a system") { _ in }
        then("it should respond") { _ in }

        given("I have a complex system") { _ in }
        when("I run the full suite") { _ in }
        then("all checks should pass") { _ in }

        given("I have a new feature") { _ in }
        then("it should be incomplete") { _ in }

        // MARK: - Outline / fruits (with_outline.feature)

        given("I have (\\d+) fruits") { match in
            Self.fruits = Int(match.captures[0])!
        }

        when("I eat (\\d+) fruits") { match in
            Self.fruits -= Int(match.captures[0])!
        }

        then("I should have (\\d+) fruits") { match in
            let expected = Int(match.captures[0])!
            XCTAssertEqual(Self.fruits, expected)
        }

        // MARK: - Data tables (with_tables.feature)

        given("the following users exist:") { match in
            Self.users = match.dataTable!.asDictionaries
        }

        when("I search for users with role \"([^\"]*)\"") { match in
            let role = match.captures[0]
            Self.searchResults = Self.users.filter { $0["role"] == role }.count
        }

        then("I should find (\\d+) users?") { match in
            let expected = Int(match.captures[0])!
            XCTAssertEqual(Self.searchResults, expected)
        }

        // MARK: - Doc strings (with_docstrings.feature)

        given("the API returns:") { match in
            Self.apiResponse = match.docString
        }

        when("I parse the response") { _ in
            // apiResponse is already stored
        }

        then("the status should be \"([^\"]*)\"") { match in
            let expected = match.captures[0]
            XCTAssertTrue(Self.apiResponse?.contains("\"\(expected)\"") == true)
        }

        given("I have a document with content:") { match in
            Self.document = match.docString
        }

        then("the document should have (\\d+) lines") { match in
            let expected = Int(match.captures[0])!
            let lineCount = Self.document?.components(separatedBy: "\n").count ?? 0
            XCTAssertEqual(lineCount, expected)
        }
    }
}
