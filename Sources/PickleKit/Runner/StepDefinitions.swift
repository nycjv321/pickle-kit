import Foundation

// MARK: - Step Definition (Declarative)

/// A single step definition declaration for use with the `StepDefinitions` protocol.
///
/// Use the static factory methods to create definitions as stored properties:
/// ```swift
/// struct MySteps: StepDefinitions {
///     let addition = StepDefinition.given("I add (\\d+)") { match in
///         // ...
///     }
/// }
/// ```
public struct StepDefinition: Sendable {
    /// The keyword for this step, or `nil` for keyword-agnostic steps.
    public let keyword: StepKeyword?
    /// The regex pattern string (without anchors).
    public let pattern: String
    /// The handler closure executed when the step matches.
    public let handler: StepHandler

    /// Create a Given step definition.
    public static func given(_ pattern: String, handler: @escaping StepHandler) -> StepDefinition {
        StepDefinition(keyword: .given, pattern: pattern, handler: handler)
    }

    /// Create a When step definition.
    public static func when(_ pattern: String, handler: @escaping StepHandler) -> StepDefinition {
        StepDefinition(keyword: .when, pattern: pattern, handler: handler)
    }

    /// Create a Then step definition.
    public static func then(_ pattern: String, handler: @escaping StepHandler) -> StepDefinition {
        StepDefinition(keyword: .then, pattern: pattern, handler: handler)
    }

    /// Create a keyword-agnostic step definition.
    public static func step(_ pattern: String, handler: @escaping StepHandler) -> StepDefinition {
        StepDefinition(keyword: nil, pattern: pattern, handler: handler)
    }

    /// Register this definition in the given registry.
    public func register(in registry: StepRegistry) {
        switch keyword {
        case .given:
            registry.given(pattern, handler: handler)
        case .when:
            registry.when(pattern, handler: handler)
        case .then:
            registry.then(pattern, handler: handler)
        default:
            registry.step(pattern, handler: handler)
        }
    }
}

// MARK: - Step Definitions Protocol

/// A type that provides step definitions for Gherkin scenarios.
///
/// Conforming types declare step definitions as stored `StepDefinition` properties.
/// The default `register(in:)` implementation uses `Mirror` to discover all stored
/// `StepDefinition` and `[StepDefinition]` properties automatically.
///
/// ```swift
/// struct ArithmeticSteps: StepDefinitions {
///     nonisolated(unsafe) static var number: Int = 0
///     init() { Self.number = 0 }
///
///     let givenNumber = StepDefinition.given("I have the number (\\d+)") { match in
///         Self.number = Int(match.captures[0])!
///     }
/// }
/// ```
///
/// Override `register(in:)` for manual registration instead of Mirror-based discovery.
public protocol StepDefinitions {
    init()
    func register(in registry: StepRegistry)
}

extension StepDefinitions {
    /// Default implementation: discovers all stored `StepDefinition` and `[StepDefinition]`
    /// properties via Mirror and registers them in the registry.
    public func register(in registry: StepRegistry) {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let current = mirror {
            for child in current.children {
                if let definition = child.value as? StepDefinition {
                    definition.register(in: registry)
                } else if let definitions = child.value as? [StepDefinition] {
                    for definition in definitions {
                        definition.register(in: registry)
                    }
                }
            }
            mirror = current.superclassMirror
        }
    }
}

// MARK: - Step Definition Filter

/// Provides environment-variable-based filtering of step definition types.
///
/// Set `CUCUMBER_STEP_DEFINITIONS` to a comma-separated list of type names
/// to restrict which `stepDefinitionTypes` are registered at runtime:
/// ```bash
/// CUCUMBER_STEP_DEFINITIONS="ArithmeticSteps,CartSteps" swift test
/// ```
public enum StepDefinitionFilter {
    /// Returns the set of type names from `CUCUMBER_STEP_DEFINITIONS`, or `nil` if unset/empty.
    public static func fromEnvironment() -> Set<String>? {
        guard let value = ProcessInfo.processInfo.environment["CUCUMBER_STEP_DEFINITIONS"],
              !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return Set(value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }
}
