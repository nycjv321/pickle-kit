# BDD as a Feedback Loop for AI-Assisted Development

BDD scenarios are human-readable specifications. When an AI coding agent implements code against those specs, test results can serve as structured feedback — the agent reads failures and iterates. PickleKit provides the foundational plumbing to enable this kind of workflow on Apple platforms, but the approach itself is still exploratory and not yet a mature, turnkey solution.

The idea is a tight loop: a human writes the spec in Gherkin, the agent implements the code, tests run, failures feed back into the agent, and the agent refines. It's the same red-green-refactor cycle developers use, with the AI agent doing the implementation work. Aspects of this workflow were used during PickleKit's own development (see below), but making it reliable and repeatable requires further exploration.

## The Workflow

```
Human writes spec (.feature) → Agent implements → Tests run → Failures → Agent fixes → Tests pass
```

1. **Human writes Gherkin feature files** — defines acceptance criteria in natural language. Each scenario is a self-contained requirement.
2. **Agent implements step definitions and app code** — translates specs into working software. The agent reads the feature files, writes the step handlers, and builds whatever application code is needed to make them pass.
3. **Run tests** — `swift test` or `xcodebuild test`. Test output includes the scenario name, the failing step, and the assertion or error message.
4. **Feed failures back to the agent** — the test output tells the agent exactly which scenarios failed and why. This is the feedback loop: structured, actionable information the agent can use to diagnose the problem.
5. **Agent fixes and iterates** — the cycle repeats until all scenarios pass.

### Why Gherkin Works Well for This

- **Natural language is native to LLMs.** Gherkin scenarios are closer to how LLMs process information than code-level test assertions.
- **Each scenario is independent.** The agent can focus on one failing scenario at a time without understanding the entire test suite.
- **Failure messages are structured and actionable.** The agent gets the scenario name, the step that failed, and the assertion — enough to localize and fix the issue.
- **The spec is stable.** Feature files don't change when the implementation does. They serve as a fixed contract between human intent and agent output.

## How PickleKit Was Built

PickleKit and its TodoApp example were built with [Claude Code](https://claude.ai/claude-code). Aspects of the BDD feedback loop described above were used during development — test failures were fed back as context to drive refinement. However, this was a manual, developer-guided process rather than a fully automated pipeline. Some development cycles were autonomous — the agent ran tests, read failures, and iterated without intervention — while others required the developer to invoke steps, interpret results, or redirect the approach.

This process was useful, though not without friction. The agent occasionally produced incorrect implementations, introduced regressions, or misunderstood requirements, and some features took several iterations to get right. Building software this way still requires an engineer with an architectural understanding of how software is made to guide the process:

- **Define clear, unambiguous specifications upfront.** Vague or incomplete specs produce vague or incomplete implementations. The quality of the Gherkin directly determines how effective the feedback loop is.
- **Recognize when test failures reflect a spec problem vs. an implementation problem.** Sometimes the agent's code is wrong; sometimes the test expectation is wrong. The human needs to make that call.
- **Catch issues that tests don't cover.** Architecture, performance, security, maintainability — none of these are validated by passing tests. A developer needs to review the agent's output with the same rigor they'd apply to a pull request from a junior engineer.
- **Make judgment calls the agent can't.** When to refactor instead of patch, when to change approach entirely, when to simplify. These decisions require understanding the broader context of the project.

The human role is not replaced — it shifts from writing every line of code to defining intent, reviewing output, and steering the process. The developer's expertise becomes more important, not less, because they're responsible for everything the tests don't catch and the agent may miss.

## Limitations and Practical Advice

**Tests only validate what they cover.** An AI agent that makes all tests pass has met the *specified* requirements, not necessarily the *intended* ones. In this workflow, thorough specs matter more than in traditional development — gaps in the spec become gaps in the implementation.

**Flaky tests are especially damaging.** A flaky test produces misleading feedback that can send the agent in the wrong direction — fixing a "failure" that was actually a timing issue, and potentially breaking something that was already working.

**Start narrow.** Well-defined, small features work better than broad, ambiguous ones. Each feature file should cover a focused area of functionality. The agent iterates more effectively when the scope is constrained and the expected behavior is explicit.

**Review every iteration.** Don't wait until all tests pass to review the agent's output. Check the implementation after each significant change — it's easier to catch architectural drift early than to unwind it after the fact.

## Current Status and Future Exploration

PickleKit provides the building blocks — a Gherkin parser, step registry, scenario runner, XCTest bridge, and HTML reporting — that make a BDD feedback loop possible on Apple platforms. The pieces are functional and tested, but the end-to-end workflow of an AI agent autonomously writing code against Gherkin specs, running tests, and iterating on failures is not a solved problem. Key areas that need further exploration include:

- **Agent-driven test execution.** Today the developer manually runs tests and feeds output back. Closing this loop — where the agent invokes `swift test` or `xcodebuild`, parses structured output, and iterates — would make the workflow significantly more practical.
- **Structured failure output.** PickleKit's test output is human-readable but not optimized for machine consumption. Structured formats (JSON, JUnit XML) that agents can parse reliably would reduce misinterpretation.
- **Spec-to-implementation reliability.** LLMs frequently misinterpret Gherkin steps or produce subtly wrong implementations. Understanding which patterns of specification lead to more reliable agent output is an open question.
- **Guardrails and review tooling.** Automated checks beyond test pass/fail — architectural conformance, diff review, regression detection — would help catch issues that tests alone miss.

This is early-stage work. If you're interested in BDD-driven AI development workflows, contributions, ideas, and feedback are welcome — open an issue or start a discussion on the [PickleKit repository](https://github.com/nycjv321/pickle-kit).
