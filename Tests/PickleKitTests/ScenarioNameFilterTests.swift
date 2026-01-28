import Testing
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
@testable import PickleKit

@Suite(.serialized)
struct ScenarioNameFilterTests {

    // MARK: - Filtering Logic

    @Test func shouldIncludeExactMatch() {
        let filter = ScenarioNameFilter(names: ["Adding two numbers"])

        #expect(filter.shouldInclude(name: "Adding two numbers"))
    }

    @Test func shouldExcludeNonMatch() {
        let filter = ScenarioNameFilter(names: ["Adding two numbers"])

        #expect(!filter.shouldInclude(name: "Subtracting two numbers"))
    }

    @Test func caseInsensitive() {
        let filter = ScenarioNameFilter(names: ["FOO BAR"])

        #expect(filter.shouldInclude(name: "Foo Bar"))
        #expect(filter.shouldInclude(name: "foo bar"))
        #expect(filter.shouldInclude(name: "FOO BAR"))
    }

    @Test func multipleNames() {
        let filter = ScenarioNameFilter(names: ["Addition", "Subtraction", "Division"])

        #expect(filter.shouldInclude(name: "Addition"))
        #expect(filter.shouldInclude(name: "Subtraction"))
        #expect(filter.shouldInclude(name: "Division"))
        #expect(!filter.shouldInclude(name: "Multiplication"))
    }

    @Test func emptyNameSetIncludesNothing() {
        let filter = ScenarioNameFilter(names: [])

        #expect(!filter.shouldInclude(name: "Anything"))
        #expect(!filter.shouldInclude(name: ""))
    }

    // MARK: - Environment Variable Parsing

    @Test func fromEnvironmentParsesCommaSeparated() {
        unsetenv("CUCUMBER_SCENARIOS")
        defer { unsetenv("CUCUMBER_SCENARIOS") }

        setenv("CUCUMBER_SCENARIOS", "Foo,Bar", 1)

        let filter = ScenarioNameFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeNames == ["foo", "bar"])
    }

    @Test func fromEnvironmentTrimsWhitespace() {
        unsetenv("CUCUMBER_SCENARIOS")
        defer { unsetenv("CUCUMBER_SCENARIOS") }

        setenv("CUCUMBER_SCENARIOS", " Foo , Bar ", 1)

        let filter = ScenarioNameFilter.fromEnvironment()
        #expect(filter != nil)
        #expect(filter?.includeNames == ["foo", "bar"])
    }

    @Test func fromEnvironmentReturnsNilWhenUnset() {
        unsetenv("CUCUMBER_SCENARIOS")
        defer { unsetenv("CUCUMBER_SCENARIOS") }

        let filter = ScenarioNameFilter.fromEnvironment()
        #expect(filter == nil)
    }

    @Test func fromEnvironmentReturnsNilWhenEmpty() {
        unsetenv("CUCUMBER_SCENARIOS")
        defer { unsetenv("CUCUMBER_SCENARIOS") }

        setenv("CUCUMBER_SCENARIOS", "", 1)

        let filter = ScenarioNameFilter.fromEnvironment()
        #expect(filter == nil)
    }

    // MARK: - Merging

    @Test func mergingCombinesSets() {
        let a = ScenarioNameFilter(names: ["Addition"])
        let b = ScenarioNameFilter(names: ["Subtraction"])

        let merged = a.merging(b)
        #expect(merged.includeNames == ["addition", "subtraction"])
    }

    @Test func mergingWithEmptyFilter() {
        let original = ScenarioNameFilter(names: ["Addition"])
        let empty = ScenarioNameFilter(names: [])

        let merged = original.merging(empty)
        #expect(merged == original)
    }

    // MARK: - Equatable

    @Test func equatable() {
        let a = ScenarioNameFilter(names: ["Addition", "Subtraction"])
        let b = ScenarioNameFilter(names: ["Addition", "Subtraction"])
        let c = ScenarioNameFilter(names: ["Division"])

        #expect(a == b)
        #expect(a != c)
    }
}
