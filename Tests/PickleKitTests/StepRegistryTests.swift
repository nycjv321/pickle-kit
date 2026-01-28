import Testing
@testable import PickleKit

@Suite struct StepRegistryTests {

    let registry: StepRegistry

    init() {
        registry = StepRegistry()
    }

    // MARK: - Registration

    @Test func registerAndCount() {
        registry.given("something") { _ in }
        registry.when("action") { _ in }
        registry.then("result") { _ in }

        #expect(registry.count == 3)
    }

    @Test func reset() {
        registry.given("a") { _ in }
        registry.when("b") { _ in }
        #expect(registry.count == 2)

        registry.reset()
        #expect(registry.count == 0)
    }

    // MARK: - Matching

    @Test func exactMatch() throws {
        registry.given("I have a cat") { _ in }

        let step = Step(keyword: .given, text: "I have a cat")
        let result = try registry.match(step)

        #expect(result != nil)
    }

    @Test func noMatch() throws {
        registry.given("I have a cat") { _ in }

        let step = Step(keyword: .given, text: "I have a dog")
        let result = try registry.match(step)

        #expect(result == nil)
    }

    @Test func regexCaptures() throws {
        registry.given("I have (\\d+) (\\w+)") { _ in }

        let step = Step(keyword: .given, text: "I have 42 apples")
        let result = try registry.match(step)

        #expect(result != nil)
        #expect(result?.match.captures == ["42", "apples"])
    }

    @Test func quotedStringCapture() throws {
        registry.given("my name is \"([^\"]*)\"") { _ in }

        let step = Step(keyword: .given, text: "my name is \"Alice\"")
        let result = try registry.match(step)

        #expect(result != nil)
        #expect(result?.match.captures == ["Alice"])
    }

    // MARK: - Keyword Agnostic

    @Test func stepMethodMatchesAnyKeyword() throws {
        registry.step("anything goes") { _ in }

        let givenStep = Step(keyword: .given, text: "anything goes")
        let whenStep = Step(keyword: .when, text: "anything goes")

        #expect(try registry.match(givenStep) != nil)
        #expect(try registry.match(whenStep) != nil)
    }

    // MARK: - Ambiguous Steps

    @Test func ambiguousStepThrows() {
        registry.given("I have .*") { _ in }
        registry.given("I have (\\d+) items") { _ in }

        let step = Step(keyword: .given, text: "I have 5 items")

        #expect {
            try registry.match(step)
        } throws: { error in
            guard let regError = error as? StepRegistryError,
                  case .ambiguousStep(_, let count) = regError else {
                return false
            }
            return count == 2
        }
    }

    // MARK: - Data Table Passthrough

    @Test func dataTablePassedToMatch() throws {
        registry.given("users exist:") { _ in }

        let table = DataTable(rows: [["name"], ["Alice"]])
        let step = Step(keyword: .given, text: "users exist:", dataTable: table)
        let result = try registry.match(step)

        #expect(result?.match.dataTable != nil)
        #expect(result?.match.dataTable?.rows.count == 2)
    }

    // MARK: - Doc String Passthrough

    @Test func docStringPassedToMatch() throws {
        registry.given("the content is:") { _ in }

        let step = Step(keyword: .given, text: "the content is:", docString: "hello world")
        let result = try registry.match(step)

        #expect(result?.match.docString == "hello world")
    }

    // MARK: - Handler Execution

    @Test func handlerExecutes() async throws {
        let box = TestBox(false)
        registry.given("I do something") { _ in
            box.value = true
        }

        let step = Step(keyword: .given, text: "I do something")
        let result = try registry.match(step)
        try await result?.handler(result!.match)

        #expect(box.value)
    }

    @Test func handlerReceivesCaptures() async throws {
        let box = TestBox<[String]>([])
        registry.when("I add (\\d+) and (\\d+)") { match in
            box.value = match.captures
        }

        let step = Step(keyword: .when, text: "I add 3 and 7")
        let result = try registry.match(step)
        try await result?.handler(result!.match)

        #expect(box.value == ["3", "7"])
    }

    // MARK: - Anchoring

    @Test func patternIsAnchored() throws {
        registry.given("exact") { _ in }

        // Should not match partial strings
        let step = Step(keyword: .given, text: "not exact match")
        #expect(try registry.match(step) == nil)
    }

    // MARK: - Invalid Patterns

    @Test func invalidPatternDoesNotCrash() {
        registry.given("I have (unclosed") { _ in }
        #expect(registry.count == 0)
    }

    @Test func invalidPatternRecordsError() throws {
        registry.given("I have (unclosed") { _ in }
        #expect(registry.registrationErrors.count == 1)
        let firstError = try #require(registry.registrationErrors.first)
        if case .invalidPattern(let pattern, _) = firstError {
            #expect(pattern == "I have (unclosed")
        } else {
            Issue.record("Expected invalidPattern error")
        }
    }

    @Test func invalidPatternErrorDescription() {
        registry.given("bad[") { _ in }
        let description = registry.registrationErrors.first?.localizedDescription ?? ""
        #expect(description.contains("bad["), "Error description should contain the pattern")
        #expect(description.contains("Invalid step pattern"), "Error description should indicate invalid pattern")
    }

    @Test func validAndInvalidPatternsMixed() {
        registry.given("valid pattern") { _ in }
        registry.given("invalid (unclosed") { _ in }
        #expect(registry.count == 1)
        #expect(registry.registrationErrors.count == 1)
    }

    @Test func resetClearsRegistrationErrors() {
        registry.given("I have (unclosed") { _ in }
        #expect(registry.registrationErrors.count == 1)
        registry.reset()
        #expect(registry.registrationErrors.isEmpty)
    }
}

/// Thread-safe mutable box for test state captured across isolation boundaries.
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
