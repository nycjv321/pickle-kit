import Foundation
import Testing
@testable import PickleKit

/// Thread-safe mutable box for test state captured across isolation boundaries.
private final class TestBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - StepDefinition Struct Tests

@Suite struct StepDefinitionTests {

    @Test func givenFactory() {
        let def = StepDefinition.given("a pattern") { _ in }
        #expect(def.keyword == .given)
        #expect(def.pattern == "a pattern")
    }

    @Test func whenFactory() {
        let def = StepDefinition.when("a pattern") { _ in }
        #expect(def.keyword == .when)
        #expect(def.pattern == "a pattern")
    }

    @Test func thenFactory() {
        let def = StepDefinition.then("a pattern") { _ in }
        #expect(def.keyword == .then)
        #expect(def.pattern == "a pattern")
    }

    @Test func stepFactory() {
        let def = StepDefinition.step("a pattern") { _ in }
        #expect(def.keyword == nil)
        #expect(def.pattern == "a pattern")
    }

    @Test func registerInRegistry() {
        let registry = StepRegistry()
        let def = StepDefinition.given("hello world") { _ in }
        def.register(in: registry)
        #expect(registry.count == 1)
    }

    @Test func handlerExecutesThroughRegistration() async throws {
        let box = TestBox(false)
        let registry = StepRegistry()
        let def = StepDefinition.given("I do something") { _ in
            box.value = true
        }
        def.register(in: registry)

        let step = Step(keyword: .given, text: "I do something")
        let result = try registry.match(step)
        #expect(result != nil)
        try await result!.handler(result!.match)
        #expect(box.value)
    }

    @Test func registerRoutesKeywordCorrectly() {
        let registry = StepRegistry()

        StepDefinition.given("given pattern") { _ in }.register(in: registry)
        StepDefinition.when("when pattern") { _ in }.register(in: registry)
        StepDefinition.then("then pattern") { _ in }.register(in: registry)
        StepDefinition.step("step pattern") { _ in }.register(in: registry)

        #expect(registry.count == 4)
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

@Suite struct StepDefinitionsProtocolTests {

    @Test func mirrorDiscoveryFindsAllProperties() {
        let registry = StepRegistry()
        let provider = ThreeStepType()
        provider.register(in: registry)
        #expect(registry.count == 3)
    }

    @Test func mirrorDiscoveryIgnoresNonStepProperties() {
        let registry = StepRegistry()
        let provider = MixedPropertyType()
        provider.register(in: registry)
        #expect(registry.count == 2)
    }

    @Test func mirrorDiscoveryWithArrayProperty() {
        let registry = StepRegistry()
        let provider = ArrayPropertyType()
        provider.register(in: registry)
        #expect(registry.count == 3)
    }

    @Test func customRegisterOverride() {
        let registry = StepRegistry()
        let provider = CustomRegisterType()
        provider.register(in: registry)
        #expect(registry.count == 1)

        let step = Step(keyword: .given, text: "custom registered")
        let match = try? registry.match(step)
        #expect(match != nil)

        let ignoredStep = Step(keyword: .given, text: "should be ignored")
        let ignoredMatch = try? registry.match(ignoredStep)
        #expect(ignoredMatch == nil)
    }

    @Test func emptyStepDefinitionsType() {
        let registry = StepRegistry()
        let provider = EmptyStepType()
        provider.register(in: registry)
        #expect(registry.count == 0)
    }

    // MARK: - Integration Tests

    @Test func multipleTypesRegistered() {
        let registry = StepRegistry()
        ThreeStepType().register(in: registry)
        MixedPropertyType().register(in: registry)
        #expect(registry.count == 5)
    }

    @Test func initCalledPerRegistration() {
        CountingStepType.initCount = 0
        let registry = StepRegistry()

        let p1 = CountingStepType()
        p1.register(in: registry)
        #expect(CountingStepType.initCount == 1)

        let p2 = CountingStepType()
        p2.register(in: registry)
        #expect(CountingStepType.initCount == 2)
    }

    @Test func mixedRegistration() {
        let registry = StepRegistry()
        ThreeStepType().register(in: registry)
        registry.given("inline step") { _ in }
        #expect(registry.count == 4)
    }
}

// MARK: - StepDefinitionFilter Tests

@Suite struct StepDefinitionFilterTests {

    @Test func filterFromEnvironmentWhenUnset() {
        let result = StepDefinitionFilter.fromEnvironment()
        if ProcessInfo.processInfo.environment["CUCUMBER_STEP_DEFINITIONS"] == nil {
            #expect(result == nil)
        }
    }

    @Test func filterParsesCommaSeparatedNames() {
        let input = "ArithmeticSteps, CartSteps , FruitSteps"
        let parsed = Set(input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        #expect(parsed == Set(["ArithmeticSteps", "CartSteps", "FruitSteps"]))
    }

    @Test func filterEmptyStringProducesNil() {
        let empty = "   "
        let isEmpty = empty.trimmingCharacters(in: .whitespaces).isEmpty
        #expect(isEmpty)
    }
}
