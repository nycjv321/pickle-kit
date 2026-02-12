# Project Setup

How to adopt PickleKit's BDD conventions in your project, including configuration for AI-assisted development with Claude Code.

For the conventions themselves, see [BDD_GUIDE.md](BDD_GUIDE.md). For the AI development workflow, see [AI-DEVELOPMENT.md](AI-DEVELOPMENT.md).

---

## 1. Add conventions as a Claude Code rule

Create `.claude/rules/bdd-conventions.md` in your project root. Copy [BDD_GUIDE.md](BDD_GUIDE.md) in its entirety — the Features and Steps sections contain the conventions Claude Code needs when writing feature files and step definitions. Claude Code auto-loads all `.claude/rules/*.md` files — no explicit reference needed in `CLAUDE.md`.

## 2. Create project-specific BDD documentation

Create a BDD document in your project (e.g., `docs/testing/BDD.md`) covering what's specific to your project. Use this template as a starting point:

````markdown
# BDD Testing

<!-- Brief description of how your project uses PickleKit. -->

## Test Suites

<!-- List each BDD suite, its test target, scenario count, and what it covers. -->

| Suite | Target | Scenarios | Coverage |
|-------|--------|-----------|----------|
| `MyFeatureBDDTests` | MyFeatureTests | N | Brief description of what scenarios validate |

## Running

```bash
# Run a specific BDD suite
swift test --filter MyFeatureBDDTests

# Run all tests in a target
swift test --filter MyFeatureTests
```

## Structure

<!-- Show where feature files and step definitions live in your project. -->

```
Features/
├── domain/
│   └── my_feature.feature

Tests/MyFeatureTests/
├── Steps/
│   ├── MyFeatureTestContext.swift
│   ├── MyFeatureSetupSteps.swift
│   ├── MyFeatureActionSteps.swift
│   └── MyFeatureVerificationSteps.swift
└── MyFeatureBDDTests.swift
```

<!-- Optional sections — include if relevant to your project. -->

<!-- ## Domain Mapping -->
<!-- Which test target covers which service area. -->

<!-- ## Fixtures -->
<!-- Where test fixtures live and how they're managed. -->

<!-- ## Testing Boundaries -->
<!-- What's tested here vs. in dependencies. -->
````

Remove the HTML comments and optional sections that don't apply once you've filled it in.

## 3. Reference project documentation in CLAUDE.md

Add your project-specific BDD document to your `CLAUDE.md` documentation references:

```markdown
## Documentation References

| Document | When to Read |
|----------|--------------|
| @docs/testing/BDD.md | BDD test suites, running, project-specific patterns |
```

Claude Code rules (`.claude/rules/*.md`) are loaded automatically — no explicit reference needed for the conventions file.

---

## What's Reusable vs. Project-Specific

| Content | Where It Lives |
|---------|---------------|
| Step design principles (business outcomes over mechanics) | Shared (BDD guide / `.claude/rules/`) |
| Feature file conventions (syntax, structure) | Shared |
| Step definition patterns (TestContext, file organization, runner) | Shared |
| Test suite inventory and scenario counts | Project-specific BDD docs |
| Domain-to-target mapping | Project-specific BDD docs |
| Running commands | Project-specific BDD docs |
| Fixture locations | Project-specific BDD docs |
| UI BDD specifics (URL schemes, page objects) | Project-specific BDD docs |
