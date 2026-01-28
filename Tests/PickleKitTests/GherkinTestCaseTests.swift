#if canImport(XCTest) && canImport(ObjectiveC)
import Testing
import XCTest
import Foundation
import PickleKit

// MARK: - Helper: Fixture Path Resolution

/// Resolves a fixture `.feature` file path from the test bundle.
/// Returns `nil` if the resource is not found.
private func fixturePath(_ name: String) -> String? {
    Bundle.module.url(forResource: name, withExtension: "feature", subdirectory: "Fixtures")?.path
}

// MARK: - Helper GherkinTestCase Subclasses
//
// These subclasses are auto-discovered by XCTest at runtime and execute their
// dynamic test suites end-to-end, providing implicit integration testing for
// the XCTest bridge pipeline (parse → expand → dynamic method generation →
// step registration → execution). All subclasses use valid fixtures with
// correct step definitions, so all auto-discovered tests pass.

/// Loads `basic.feature` via `featurePaths` with `ArithmeticSteps`.
final class BasicBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("basic").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [ArithmeticSteps.self]
    }
}

/// Loads `with_tags.feature` via `featurePaths` with `TaggedSteps`, excluding `@wip`.
final class TagExcludeBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("with_tags").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [TaggedSteps.self]
    }
    override class var tagFilter: TagFilter? {
        TagFilter(excludeTags: ["wip"])
    }
}

/// Loads `with_tags.feature` via `featurePaths` with `TaggedSteps`, including only `@fast`.
final class TagIncludeBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("with_tags").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [TaggedSteps.self]
    }
    override class var tagFilter: TagFilter? {
        TagFilter(includeTags: ["fast"])
    }
}

/// Loads all fixtures via `featureBundle`/`featureSubdirectory` with all step types.
final class AllFixturesBridgeTestCase: GherkinTestCase {
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

/// Points to a nonexistent subdirectory, producing 0 tests.
final class EmptySubdirBridgeTestCase: GherkinTestCase {
    override class var featureBundle: Bundle { Bundle.module }
    override class var featureSubdirectory: String? { "NonexistentSubdir" }
}

/// Loads `with_outline.feature` via `featurePaths` with `FruitSteps`.
final class OutlineBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("with_outline").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [FruitSteps.self]
    }
}

/// Loads `with_background.feature` via `featurePaths` with `ShoppingCartSteps`.
final class BackgroundBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("with_background").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [ShoppingCartSteps.self]
    }
}

/// Loads `with_tables.feature` via `featurePaths` with `DataTableSteps`.
final class TablesBridgeTestCase: GherkinTestCase {
    override class var featurePaths: [String]? {
        fixturePath("with_tables").map { [$0] }
    }
    override class var stepDefinitionTypes: [any StepDefinitions.Type] {
        [DataTableSteps.self]
    }
}

// MARK: - GherkinTestCase Tests

/// Tests for `GherkinTestCase` — the XCTest bridge that generates dynamic test suites
/// from Gherkin feature files using the ObjC runtime.
///
/// Count-sensitive assertions use direct feature parsing (via `GherkinParser` +
/// `OutlineExpander` + `TagFilter`) instead of calling `defaultTestSuite`, which
/// reads `TagFilter.fromEnvironment()` and `CUCUMBER_FEATURES` internally. This
/// avoids a race condition with `TagFilterTests` setting those env vars concurrently.
///
/// The helper subclasses above are auto-discovered by XCTest and serve as the
/// integration test for the full `defaultTestSuite` pipeline — they run all fixture
/// scenarios end-to-end during the XCTest phase of `swift test`.
@Suite(.serialized)
struct GherkinTestCaseTests {

    // MARK: - Helpers

    /// Count scenarios from a single fixture feature file, applying an optional tag filter.
    /// Bypasses `defaultTestSuite` (which reads env vars) by parsing directly.
    private func scenarioCount(
        fixture: String,
        tagFilter: TagFilter? = nil
    ) throws -> Int {
        let path = try #require(fixturePath(fixture))
        let parser = GherkinParser()
        let feature = try parser.parseFile(at: path)
        let expanded = OutlineExpander().expand(feature)
        var count = 0
        for definition in expanded.scenarios {
            guard case .scenario(let scenario) = definition else { continue }
            if let filter = tagFilter {
                let allTags = feature.tags + scenario.tags
                if !filter.shouldInclude(tags: allTags) { continue }
            }
            count += 1
        }
        return count
    }

    /// Count scenarios from all fixtures in the bundle, applying an optional tag filter.
    private func allFixturesScenarioCount(tagFilter: TagFilter? = nil) throws -> Int {
        let parser = GherkinParser()
        let features = try parser.parseBundle(bundle: Bundle.module, subdirectory: "Fixtures")
        let expander = OutlineExpander()
        var count = 0
        for feature in features {
            let expanded = expander.expand(feature)
            for definition in expanded.scenarios {
                guard case .scenario(let scenario) = definition else { continue }
                if let filter = tagFilter {
                    let allTags = feature.tags + scenario.tags
                    if !filter.shouldInclude(tags: allTags) { continue }
                }
                count += 1
            }
        }
        return count
    }

    // MARK: - Expected Scenario Counts

    @Test func basicFeatureHasTwoScenarios() throws {
        #expect(try scenarioCount(fixture: "basic") == 2)
    }

    @Test func outlineExpansionProducesThreeScenarios() throws {
        #expect(try scenarioCount(fixture: "with_outline") == 3)
    }

    @Test func backgroundFeatureHasTwoScenarios() throws {
        #expect(try scenarioCount(fixture: "with_background") == 2)
    }

    @Test func allFixturesProduceThirteenScenarios() throws {
        #expect(try allFixturesScenarioCount() == 13)
    }

    @Test func tablesFeatureHasOneScenario() throws {
        #expect(try scenarioCount(fixture: "with_tables") == 1)
    }

    // MARK: - Tag Filtering

    @Test func tagFilterExcludesFromFixture() throws {
        let count = try scenarioCount(
            fixture: "with_tags",
            tagFilter: TagFilter(excludeTags: ["wip"])
        )
        #expect(count == 2)
    }

    @Test func tagFilterIncludeReducesFixture() throws {
        let count = try scenarioCount(
            fixture: "with_tags",
            tagFilter: TagFilter(includeTags: ["fast"])
        )
        #expect(count == 1)
    }

    // MARK: - Subclass Configuration

    @Test func featurePathsPropertyOverridesBundle() {
        // BasicBridgeTestCase.featurePaths points to basic.feature only,
        // confirming the featurePaths override exists (not nil) and is a
        // single-element array. This overrides the default bundle loading.
        let paths = BasicBridgeTestCase.featurePaths
        #expect(paths != nil)
        #expect(paths?.count == 1)
        #expect(paths?[0].hasSuffix("basic.feature") == true)
    }

    @Test func stepDefinitionTypesProperty() {
        let types = BasicBridgeTestCase.stepDefinitionTypes
        #expect(types.count == 1)
        #expect(ObjectIdentifier(types[0]) == ObjectIdentifier(ArithmeticSteps.self))
    }

    @Test func tagFilterProperty() {
        #expect(BasicBridgeTestCase.tagFilter == nil)
        #expect(TagExcludeBridgeTestCase.tagFilter == TagFilter(excludeTags: ["wip"]))
        #expect(TagIncludeBridgeTestCase.tagFilter == TagFilter(includeTags: ["fast"]))
    }

    @Test func featureBundleAndSubdirectoryProperties() {
        #expect(AllFixturesBridgeTestCase.featureSubdirectory == "Fixtures")
        #expect(EmptySubdirBridgeTestCase.featureSubdirectory == "NonexistentSubdir")
    }

    // MARK: - Registry

    @Test func registryIsInstanceBased() {
        let a = BasicBridgeTestCase()
        let b = BasicBridgeTestCase()
        #expect(a.registry !== b.registry)
    }

    @Test func convenienceRegistrationMethods() {
        let tc = BasicBridgeTestCase()
        #expect(tc.registry.count == 0)
        tc.given("pattern one") { _ in }
        #expect(tc.registry.count == 1)
        tc.when("pattern two") { _ in }
        #expect(tc.registry.count == 2)
        tc.then("pattern three") { _ in }
        #expect(tc.registry.count == 3)
        tc.step("pattern four") { _ in }
        #expect(tc.registry.count == 4)
    }
}
#endif
