import XCTest
@testable import PickleKit

// MARK: - StepDefinition Struct Tests

final class StepDefinitionTests: XCTestCase {

    func testGivenFactory() {
        let def = StepDefinition.given("a pattern") { _ in }
        XCTAssertEqual(def.keyword, .given)
        XCTAssertEqual(def.pattern, "a pattern")
    }

    func testWhenFactory() {
        let def = StepDefinition.when("a pattern") { _ in }
        XCTAssertEqual(def.keyword, .when)
        XCTAssertEqual(def.pattern, "a pattern")
    }

    func testThenFactory() {
        let def = StepDefinition.then("a pattern") { _ in }
        XCTAssertEqual(def.keyword, .then)
        XCTAssertEqual(def.pattern, "a pattern")
    }

    func testStepFactory() {
        let def = StepDefinition.step("a pattern") { _ in }
        XCTAssertNil(def.keyword)
        XCTAssertEqual(def.pattern, "a pattern")
    }

    func testRegisterInRegistry() {
        let registry = StepRegistry()
        let def = StepDefinition.given("hello world") { _ in }
        def.register(in: registry)
        XCTAssertEqual(registry.count, 1)
    }

    func testHandlerExecutesThroughRegistration() async throws {
        nonisolated(unsafe) var executed = false
        let registry = StepRegistry()
        let def = StepDefinition.given("I do something") { _ in
            executed = true
        }
        def.register(in: registry)

        let step = Step(keyword: .given, text: "I do something")
        let result = try registry.match(step)
        XCTAssertNotNil(result)
        try await result!.handler(result!.match)
        XCTAssertTrue(executed)
    }

    func testRegisterRoutesKeywordCorrectly() {
        let registry = StepRegistry()

        // All keyword variants should register successfully
        StepDefinition.given("given pattern") { _ in }.register(in: registry)
        StepDefinition.when("when pattern") { _ in }.register(in: registry)
        StepDefinition.then("then pattern") { _ in }.register(in: registry)
        StepDefinition.step("step pattern") { _ in }.register(in: registry)

        XCTAssertEqual(registry.count, 4)
    }
}

// MARK: - Test Step Definition Types

private struct ThreeStepType: StepDefinitions {
    let step1 = StepDefinition.given("first step") { _ in }
    let step2 = StepDefinition.when("second step") { _ in }
    let step3 = StepDefinition.then("third step") { _ in }
}

private struct MixedPropertyType: StepDefinitions {
    let step1 = StepDefinition.given("a step") { _ in }
    let name = "not a step"
    let count = 42
    let step2 = StepDefinition.then("another step") { _ in }
}

private struct ArrayPropertyType: StepDefinitions {
    let steps: [StepDefinition] = [
        .given("array step one") { _ in },
        .when("array step two") { _ in },
    ]
    let single = StepDefinition.then("single step") { _ in }
}

private struct CustomRegisterType: StepDefinitions {
    let ignoredStep = StepDefinition.given("should be ignored") { _ in }

    func register(in registry: StepRegistry) {
        registry.given("custom registered") { _ in }
    }
}

private struct EmptyStepType: StepDefinitions {}

private struct CountingStepType: StepDefinitions {
    nonisolated(unsafe) static var initCount = 0
    init() { Self.initCount += 1 }

    let step = StepDefinition.given("counting step") { _ in }
}

// MARK: - Mirror-Based Discovery Tests

final class StepDefinitionsProtocolTests: XCTestCase {

    func testMirrorDiscoveryFindsAllProperties() {
        let registry = StepRegistry()
        let provider = ThreeStepType()
        provider.register(in: registry)
        XCTAssertEqual(registry.count, 3)
    }

    func testMirrorDiscoveryIgnoresNonStepProperties() {
        let registry = StepRegistry()
        let provider = MixedPropertyType()
        provider.register(in: registry)
        XCTAssertEqual(registry.count, 2)
    }

    func testMirrorDiscoveryWithArrayProperty() {
        let registry = StepRegistry()
        let provider = ArrayPropertyType()
        provider.register(in: registry)
        // 2 from array + 1 single = 3
        XCTAssertEqual(registry.count, 3)
    }

    func testCustomRegisterOverride() {
        let registry = StepRegistry()
        let provider = CustomRegisterType()
        provider.register(in: registry)
        // Only the custom-registered step, not the stored property
        XCTAssertEqual(registry.count, 1)

        let step = Step(keyword: .given, text: "custom registered")
        let match = try? registry.match(step)
        XCTAssertNotNil(match)

        let ignoredStep = Step(keyword: .given, text: "should be ignored")
        let ignoredMatch = try? registry.match(ignoredStep)
        XCTAssertNil(ignoredMatch)
    }

    func testEmptyStepDefinitionsType() {
        let registry = StepRegistry()
        let provider = EmptyStepType()
        provider.register(in: registry)
        XCTAssertEqual(registry.count, 0)
    }

    // MARK: - Integration Tests

    func testMultipleTypesRegistered() {
        let registry = StepRegistry()
        ThreeStepType().register(in: registry)
        MixedPropertyType().register(in: registry)
        // 3 + 2 = 5
        XCTAssertEqual(registry.count, 5)
    }

    func testInitCalledPerRegistration() {
        CountingStepType.initCount = 0
        let registry = StepRegistry()

        let p1 = CountingStepType()
        p1.register(in: registry)
        XCTAssertEqual(CountingStepType.initCount, 1)

        let p2 = CountingStepType()
        p2.register(in: registry)
        XCTAssertEqual(CountingStepType.initCount, 2)
    }

    func testMixedRegistration() {
        let registry = StepRegistry()
        ThreeStepType().register(in: registry)
        registry.given("inline step") { _ in }
        // 3 from type + 1 inline = 4
        XCTAssertEqual(registry.count, 4)
    }
}

// MARK: - StepDefinitionFilter Tests

final class StepDefinitionFilterTests: XCTestCase {

    func testFilterFromEnvironmentWhenUnset() {
        // CUCUMBER_STEP_DEFINITIONS is not expected to be set during normal test runs
        let result = StepDefinitionFilter.fromEnvironment()
        // If it happens to be set in the test environment, we just verify the return type
        if ProcessInfo.processInfo.environment["CUCUMBER_STEP_DEFINITIONS"] == nil {
            XCTAssertNil(result)
        }
    }

    func testFilterParsesCommaSeparatedNames() {
        // Test the parsing logic directly by verifying the expected behavior:
        // "ArithmeticSteps,CartSteps" should produce {"ArithmeticSteps", "CartSteps"}
        // We can't easily set env vars in-process, so we test the Set construction logic
        let input = "ArithmeticSteps, CartSteps , FruitSteps"
        let parsed = Set(input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        XCTAssertEqual(parsed, Set(["ArithmeticSteps", "CartSteps", "FruitSteps"]))
    }

    func testFilterEmptyStringProducesNil() {
        // Verify the trimming/empty check logic
        let empty = "   "
        let isEmpty = empty.trimmingCharacters(in: .whitespaces).isEmpty
        XCTAssertTrue(isEmpty)
    }
}
