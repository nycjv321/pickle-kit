# BDD as a Feedback Loop for AI-Assisted Development

BDD scenarios are human-readable specifications. When an AI coding agent implements code against those specs, test results become structured, automated feedback — the agent can read failures and iterate without manual intervention.

This creates a tight loop: a human writes the spec in Gherkin, the agent implements the code, tests run, failures feed back into the agent, and the agent refines. It's the same red-green-refactor cycle developers use, with the AI agent doing the implementation work.

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

PickleKit and its TodoApp example were built with [Claude Code](https://claude.ai/claude-code). Test failures were the primary mechanism for driving refinement — when the agent produced code that didn't work, the failing test output was fed back as context, and the agent used that feedback to diagnose and fix the issue.

This process worked, but it was not seamless. The agent produced incorrect implementations, introduced regressions, and sometimes misunderstood the requirements. Many iterations were needed to reach a working state. Building software this way requires a developer with strong technical judgment to guide the process:

- **Define clear, unambiguous specifications upfront.** Vague or incomplete specs produce vague or incomplete implementations. The quality of the Gherkin directly determines how effective the feedback loop is.
- **Recognize when test failures reflect a spec problem vs. an implementation problem.** Sometimes the agent's code is wrong; sometimes the test expectation is wrong. The human needs to make that call.
- **Catch issues that tests don't cover.** Architecture, performance, security, maintainability — none of these are validated by passing tests. A developer needs to review the agent's output with the same rigor they'd apply to a pull request from a junior engineer.
- **Make judgment calls the agent can't.** When to refactor instead of patch, when to change approach entirely, when to simplify. These decisions require understanding the broader context of the project.

The human role is not replaced — it shifts from writing every line of code to defining intent, reviewing output, and steering the process. The developer's expertise becomes more important, not less, because they're responsible for everything the tests don't catch.

## Limitations and Practical Advice

**Tests only validate what they cover.** An AI agent that makes all tests pass has met the *specified* requirements, not necessarily the *intended* ones. In this workflow, thorough specs matter more than in traditional development — gaps in the spec become gaps in the implementation.

**Flaky tests are especially damaging.** A flaky test produces misleading feedback that can send the agent in the wrong direction — fixing a "failure" that was actually a timing issue, and potentially breaking something that was already working.

**Start narrow.** Well-defined, small features work better than broad, ambiguous ones. Each feature file should cover a focused area of functionality. The agent iterates more effectively when the scope is constrained and the expected behavior is explicit.

**Review every iteration.** Don't wait until all tests pass to review the agent's output. Check the implementation after each significant change — it's easier to catch architectural drift early than to unwind it after the fact.
