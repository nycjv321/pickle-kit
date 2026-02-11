# Project Setup

How to adopt PickleKit's BDD conventions in your project, including configuration for AI-assisted development with Claude Code.

For the conventions themselves, see [BDD_GUIDE.md](BDD_GUIDE.md). For the AI development workflow, see [AI-DEVELOPMENT.md](AI-DEVELOPMENT.md).

---

## 1. Add conventions as a Claude Code rule

Create `.claude/rules/bdd-conventions.md` in your project root. Copy the content from the [Features](BDD_GUIDE.md#features) and [Steps](BDD_GUIDE.md#steps) sections of the BDD Conventions Guide. Claude Code auto-loads all `.claude/rules/*.md` files — no explicit reference needed in `CLAUDE.md`.

## 2. Create project-specific BDD documentation

Your project's own BDD documentation (e.g., `docs/testing/BDD.md`) should cover what's specific to your project:

- **Test suite inventory** — which suites exist, scenario counts, what each covers
- **Running commands** — `swift test --filter ...` for each suite
- **Directory structure** — where features and steps live in your project
- **Domain-to-target mapping** — which test target covers which service area
- **Fixture locations** — where test fixtures live and how they're managed
- **Testing boundaries** — what's tested here vs. in dependencies (if applicable)
- **UI BDD specifics** — URL schemes, page objects, accessibility identifiers (if applicable)

## 3. Reference project documentation in CLAUDE.md

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
