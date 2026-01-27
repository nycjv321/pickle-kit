import XCTest
import PickleKit

// MARK: - Domain Step Definition Types

/// Step definitions for basic.feature (arithmetic scenarios).
struct ArithmeticSteps: StepDefinitions {
    nonisolated(unsafe) static var number: Int = 0
    init() { Self.number = 0 }

    let givenNumber = StepDefinition.given("I have the number (\\d+)") { match in
        Self.number = Int(match.captures[0])!
    }

    let addNumber = StepDefinition.when("I add (\\d+)") { match in
        Self.number += Int(match.captures[0])!
    }

    let subtractNumber = StepDefinition.when("I subtract (\\d+)") { match in
        Self.number -= Int(match.captures[0])!
    }

    let resultShouldBe = StepDefinition.then("the result should be (\\d+)") { match in
        let expected = Int(match.captures[0])!
        XCTAssertEqual(Self.number, expected)
    }
}

/// Step definitions for with_background.feature (shopping cart scenarios).
struct ShoppingCartSteps: StepDefinitions {
    nonisolated(unsafe) static var cart: [String] = []
    nonisolated(unsafe) static var loggedInUser: String? = nil
    init() {
        Self.cart = []
        Self.loggedInUser = nil
    }

    let emptyCart = StepDefinition.given("I have an empty cart") { _ in
        Self.cart = []
    }

    let loggedIn = StepDefinition.given("I am logged in as \"([^\"]*)\"") { match in
        Self.loggedInUser = match.captures[0]
    }

    let addToCart = StepDefinition.when("I add \"([^\"]*)\" to the cart") { match in
        Self.cart.append(match.captures[0])
    }

    let cartCount = StepDefinition.then("the cart should contain (\\d+) items?") { match in
        let expected = Int(match.captures[0])!
        XCTAssertEqual(Self.cart.count, expected)
    }
}

/// Step definitions for with_tags.feature (tagged scenario no-ops).
struct TaggedSteps: StepDefinitions {
    let haveSystem = StepDefinition.given("I have a system") { _ in }
    let shouldRespond = StepDefinition.then("it should respond") { _ in }

    let complexSystem = StepDefinition.given("I have a complex system") { _ in }
    let runFullSuite = StepDefinition.when("I run the full suite") { _ in }
    let allChecksPass = StepDefinition.then("all checks should pass") { _ in }

    let newFeature = StepDefinition.given("I have a new feature") { _ in }
    let shouldBeIncomplete = StepDefinition.then("it should be incomplete") { _ in }
}

/// Step definitions for with_outline.feature (fruit scenarios).
struct FruitSteps: StepDefinitions {
    nonisolated(unsafe) static var fruits: Int = 0
    init() { Self.fruits = 0 }

    let haveFruits = StepDefinition.given("I have (\\d+) fruits") { match in
        Self.fruits = Int(match.captures[0])!
    }

    let eatFruits = StepDefinition.when("I eat (\\d+) fruits") { match in
        Self.fruits -= Int(match.captures[0])!
    }

    let shouldHaveFruits = StepDefinition.then("I should have (\\d+) fruits") { match in
        let expected = Int(match.captures[0])!
        XCTAssertEqual(Self.fruits, expected)
    }
}

/// Step definitions for with_tables.feature (data table scenarios).
struct DataTableSteps: StepDefinitions {
    nonisolated(unsafe) static var users: [[String: String]] = []
    nonisolated(unsafe) static var searchResults: Int = 0
    init() {
        Self.users = []
        Self.searchResults = 0
    }

    let usersExist = StepDefinition.given("the following users exist:") { match in
        Self.users = match.dataTable!.asDictionaries
    }

    let searchByRole = StepDefinition.when("I search for users with role \"([^\"]*)\"") { match in
        let role = match.captures[0]
        Self.searchResults = Self.users.filter { $0["role"] == role }.count
    }

    let findUsers = StepDefinition.then("I should find (\\d+) users?") { match in
        let expected = Int(match.captures[0])!
        XCTAssertEqual(Self.searchResults, expected)
    }
}

/// Step definitions for with_docstrings.feature (doc string scenarios).
struct DocStringSteps: StepDefinitions {
    nonisolated(unsafe) static var apiResponse: String? = nil
    nonisolated(unsafe) static var document: String? = nil
    init() {
        Self.apiResponse = nil
        Self.document = nil
    }

    let apiReturns = StepDefinition.given("the API returns:") { match in
        Self.apiResponse = match.docString
    }

    let parseResponse = StepDefinition.when("I parse the response") { _ in
        // apiResponse is already stored
    }

    let statusShouldBe = StepDefinition.then("the status should be \"([^\"]*)\"") { match in
        let expected = match.captures[0]
        XCTAssertTrue(Self.apiResponse?.contains("\"\(expected)\"") == true)
    }

    let documentWithContent = StepDefinition.given("I have a document with content:") { match in
        Self.document = match.docString
    }

    let documentLineCount = StepDefinition.then("the document should have (\\d+) lines") { match in
        let expected = Int(match.captures[0])!
        let lineCount = Self.document?.components(separatedBy: "\n").count ?? 0
        XCTAssertEqual(lineCount, expected)
    }
}

// MARK: - Integration Test Case

/// Integration test that runs fixture .feature files through GherkinTestCase.
/// This exercises the full pipeline: parsing -> outline expansion -> dynamic test
/// generation -> step execution -> report collection.
///
/// Also enables HTML report generation via `PICKLE_REPORT=1 swift test`.
final class GherkinIntegrationTests: GherkinTestCase {

    override class var featureBundle: Bundle { Bundle.module }
    override class var featureSubdirectory: String? { "Fixtures" }

    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [
            ArithmeticSteps.self,
            ShoppingCartSteps.self,
            TaggedSteps.self,
            FruitSteps.self,
            DataTableSteps.self,
            DocStringSteps.self,
        ]
    }
}
