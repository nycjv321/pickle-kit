import Testing
import Foundation
import PickleKit

// MARK: - Assertion Error for Step Handlers

/// Lightweight error type for step handler assertion failures.
/// Since step handlers run inside `ScenarioRunner` (not directly in a Swift Testing context),
/// XCTest assertions won't propagate. Instead, throw this error to signal failure.
private struct StepAssertionError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

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
        guard Self.number == expected else {
            throw StepAssertionError(message: "Expected \(expected) but got \(Self.number)")
        }
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
        guard Self.cart.count == expected else {
            throw StepAssertionError(message: "Expected cart count \(expected) but got \(Self.cart.count)")
        }
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
        guard Self.fruits == expected else {
            throw StepAssertionError(message: "Expected \(expected) fruits but got \(Self.fruits)")
        }
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
        guard Self.searchResults == expected else {
            throw StepAssertionError(message: "Expected \(expected) users but got \(Self.searchResults)")
        }
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
        guard Self.apiResponse?.contains("\"\(expected)\"") == true else {
            throw StepAssertionError(message: "API response does not contain status \"\(expected)\"")
        }
    }

    let documentWithContent = StepDefinition.given("I have a document with content:") { match in
        Self.document = match.docString
    }

    let documentLineCount = StepDefinition.then("the document should have (\\d+) lines") { match in
        let expected = Int(match.captures[0])!
        let lineCount = Self.document?.components(separatedBy: "\n").count ?? 0
        guard lineCount == expected else {
            throw StepAssertionError(message: "Expected \(expected) lines but got \(lineCount)")
        }
    }
}

// MARK: - Integration Test Suite

/// Integration test that runs fixture .feature files through GherkinTestScenario.
/// This exercises the full pipeline: parsing -> outline expansion -> parameterized
/// test generation -> step execution.
///
/// Uses `@Suite(.serialized)` because step definition types use `nonisolated(unsafe)
/// static var` state that gets reset per-scenario via `init()` — parallel execution
/// would cause data races.
@Suite(.serialized)
struct GherkinIntegrationTests {

    static let allScenarios = GherkinTestScenario.scenarios(
        bundle: Bundle.module,
        subdirectory: "Fixtures"
    )

    @Test(arguments: GherkinIntegrationTests.allScenarios)
    func scenario(_ test: GherkinTestScenario) async throws {
        let result = try await test.run(stepDefinitions: [
            ArithmeticSteps.self,
            ShoppingCartSteps.self,
            TaggedSteps.self,
            FruitSteps.self,
            DataTableSteps.self,
            DocStringSteps.self,
        ])
        #expect(result.passed, "Scenario '\(test.scenario.name)' failed: \(result.error?.localizedDescription ?? "unknown error")")
    }
}
