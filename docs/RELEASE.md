# Release Process

This document explains how CucumberAndApples's automated release process works.

## Overview

CucumberAndApples uses an automated CI/CD pipeline powered by:
- **GitHub Actions** for CI and release automation
- **release-please** for automated version bumps and changelog generation
- **Conventional Commits** for semantic versioning

When commits following the conventional commit format are pushed to `main`, release-please automatically creates or updates a release PR. Merging that PR triggers a new release with a git tag that consumers can reference in their `Package.swift`.

## Repository Setup

Before release-please can create pull requests, you must enable the required GitHub Actions permission:

1. Go to your repository's **Settings** > **Actions** > **General**
2. Scroll to **Workflow permissions**
3. Enable **"Allow GitHub Actions to create and approve pull requests"**
4. Click **Save**

Without this setting, release-please will fail with: "GitHub Actions is not permitted to create or approve pull requests".

## Conventional Commits

All commits should follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types and Version Bumps

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor (0.x.0) |
| `fix` | Bug fix | Patch (0.0.x) |
| `docs` | Documentation only | None |
| `style` | Formatting, no code change | None |
| `refactor` | Code change that neither fixes nor adds | None |
| `perf` | Performance improvement | Patch (0.0.x) |
| `test` | Adding/updating tests | None |
| `chore` | Maintenance tasks | None |
| `ci` | CI/CD changes | None |

### Breaking Changes

Breaking changes trigger a major version bump (x.0.0). Mark them with either:
- Add `!` after the type: `feat!: change TagFilter API`
- Add `BREAKING CHANGE:` in the commit footer

### Examples

```bash
# Feature (minor bump)
git commit -m "feat: add environment variable tag filtering"

# Bug fix (patch bump)
git commit -m "fix: trim whitespace in parsed tag values"

# Breaking change (major bump)
git commit -m "feat!: rename StepMatch.captures to StepMatch.groups"

# With scope
git commit -m "feat(parser): add Rule keyword support"

# With body
git commit -m "fix: handle empty examples table in outline expansion

The OutlineExpander now returns zero scenarios instead of
crashing when an Examples table has no data rows."
```

## CI Pipeline

The CI workflow (`.github/workflows/ci.yml`) runs on:
- Pushes to `main` branch
- Pushes to `feature/*` branches
- Pull requests targeting `main`

### Jobs

#### Test Job

Runs on `macos-14`:
1. Checkout code
2. Setup Xcode (latest stable)
3. Install xcbeautify
4. Cache and resolve SPM dependencies
5. Run tests with code coverage
6. Generate JUnit test report via xcbeautify
7. Generate LCOV coverage report
8. Upload test results artifact (retained 7 days)
9. Publish test report via dorny/test-reporter

#### Build Job

Runs after tests pass:
1. Checkout code
2. Setup Xcode (latest stable)
3. Build in release configuration (`swift build -c release`)

## Release Workflow

The release workflow (`.github/workflows/release.yml`) runs after successful CI on `main`.

### How release-please Works

1. **Commit Analysis**: release-please analyzes commits since the last release
2. **Release PR**: Creates/updates a PR with:
   - Version bump based on conventional commits
   - Updated CHANGELOG.md
   - Version updates in relevant files
3. **Release Creation**: When the release PR is merged:
   - A new GitHub release is created
   - A git tag is created (e.g., `v0.2.0`)

### Consuming Releases

Users reference releases in their `Package.swift`:

```swift
.package(url: "https://github.com/nycjv321/cucumber-and-apples.git", from: "0.1.0")
```

Swift Package Manager resolves tags automatically, so each release-please tag makes a new version available to consumers.

## GITHUB_TOKEN

The workflows use the automatic `GITHUB_TOKEN` provided by GitHub Actions. No manual token setup is required.

### Permissions Used

| Workflow | Permission | Purpose |
|----------|-----------|---------|
| CI | `contents: read` | Checkout code |
| CI | `checks: write` | Publish test report |
| Release | `contents: write` | Create releases and tags |
| Release | `pull-requests: write` | Create and update release PRs |

## Manual Steps

### Merging Release PRs

When release-please creates a release PR:

1. Review the proposed version bump and changelog
2. Verify CI checks pass
3. Merge the PR (squash or merge commit both work)
4. The release and tag are created automatically

### Verifying Releases

After merging a release PR:

1. Go to the repository's **Releases** page
2. Verify the new release appears with the correct tag
3. Confirm a consumer project can resolve the new version:
   ```bash
   swift package resolve
   ```

## Troubleshooting

### Release PR Not Created

**Cause**: No releasable commits since last release.

**Solution**: Ensure commits use conventional commit format with types that trigger releases (`feat`, `fix`, `perf`).

### Version Bump Incorrect

**Cause**: Commits don't follow conventional commit format exactly.

**Solution**:
- Ensure no typos in commit type (`feat` not `feature`)
- Breaking changes need `!` or `BREAKING CHANGE:` footer
- The scope is optional but must be in parentheses: `feat(parser):`

### Tests Failing in CI

**Cause**: Code works locally but fails in CI.

**Solution**:
- CI runs on `macos-14` — check Xcode version differences
- Verify Swift version compatibility (5.9+)
- Check if tests depend on file system state or environment variables
- Review xcbeautify output in the CI logs

### Release PR Permission Error

**Cause**: "GitHub Actions is not permitted to create or approve pull requests"

**Solution**: Enable PR creation in repository settings. See [Repository Setup](#repository-setup) section above.

### Release PR Not Mergeable

**Cause**: Branch protection requires CI status checks to pass before merging.

**Solution**: Wait for CI to complete on the release PR. The merge button will become enabled once the `build` check passes.

### CI Passes but Release Doesn't Run

**Cause**: Release workflow only runs after CI workflow completes successfully on `main`.

**Solution**: Check the Actions tab to verify CI workflow completed with success status. The release workflow triggers on `workflow_run` completion of the CI workflow.

### Test Report Not Published

**Cause**: `dorny/test-reporter` can't find `junit.xml` or lacks permissions.

**Solution**:
- Check the "Verify test report" step output to confirm `junit.xml` was generated
- Ensure the CI workflow has `permissions: checks: write`
- Verify xcbeautify is installed and `--report junit --report-path .` flags are present
