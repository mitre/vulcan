# Vulcan Release Process

## Overview

Releases are tag-triggered. Push a semver tag to master and the automation handles the rest:

1. `release.yml` fires on the tag, runs git-cliff to generate a changelog, creates the GitHub Release
2. `ci.yml` fires on `release: [published]`, runs the full test suite, then builds and pushes multi-arch Docker images

You do not manually create draft releases, write changelog entries, or push Docker images.

## CI/CD Workflow Files

| File | Purpose |
|------|---------|
| `ci.yml` | Lint, test (frontend + backend shards), SonarCloud, Docker release on publish |
| `release.yml` | Tag-triggered: generate changelog via git-cliff, create GitHub Release, commit CHANGELOG.md |
| `docs.yml` | Deploy VitePress documentation to GitHub Pages |
| `dependabot.yml` | Auto-approve and merge Dependabot PRs |

## Prerequisites

- Push access to the Vulcan repository (to push tags)
- All work merged to master via PRs with conventional commit messages
- CI passing on master

## Conventional Commits

git-cliff reads commit messages to build the changelog. Every commit merged to master should follow the [Conventional Commits](https://www.conventionalcommits.org) format:

```
<type>[optional scope]: <description>

Examples:
feat: add OIDC provider support
fix: correct rule export when description is blank
refactor: extract XCCDF parser into dedicated class
test: add request specs for component export
docs: document AC-8 consent TTL configuration
chore: update Ruby to 3.4.9
```

### How commit types map to changelog sections

| Commit prefix | Changelog section |
|---------------|------------------|
| `feat:` | Added |
| `fix:` | Fixed |
| `refactor:`, `perf:` | Changed |
| `test:` | Tests |
| `doc:`, `docs:` | Documentation |
| `chore:` | Maintenance |
| `style:`, `ci:` | (skipped — not shown in changelog) |
| commit body contains `security` | Security |

Commits that do not follow conventional format are filtered out of the changelog entirely (`filter_unconventional = true` in `cliff.toml`).

### Semver guidance

Choose the version bump based on what is in the release:

- **Patch** (v2.3.x): bug fixes, dependency updates, maintenance
- **Minor** (v2.x.0): new user-facing features
- **Major** (vX.0.0): breaking changes — discuss with the team first

## Step-by-Step Release Process

### 1. Confirm master is ready

```bash
git checkout master
git pull origin master
```

Verify CI is green on master in the [Actions tab](https://github.com/mitre/vulcan/actions).

### 2. Update the VERSION file

The VERSION file is the single source of truth. Edit it directly:

```bash
# Example: bumping from v2.3.1 to v2.3.2
echo "v2.3.2" > VERSION
```

Sync the version to `package.json`:

```bash
bundle exec rake version:sync
```

Commit and push:

```bash
git add VERSION package.json
git commit -m "chore: bump version to v2.3.2"
git push origin master
```

Wait for CI to pass on that commit before tagging.

### 3. Tag and push

```bash
git tag v2.3.2
git push origin v2.3.2
```

That push triggers everything. No further manual steps are required.

### 4. What happens automatically

**`release.yml`** (triggered by the tag push):

1. Checks out full history (`fetch-depth: 0`)
2. Runs git-cliff with `--latest --strip header` to generate the changelog for this release only
3. Creates a GitHub Release with the generated changelog as the body
4. Runs git-cliff again for the full CHANGELOG.md
5. Commits `CHANGELOG.md` back to master via `github-actions[bot]`

**`ci.yml`** (triggered by `release: [published]`):

1. Runs the full lint + frontend + backend test suite
2. If all jobs pass, runs `docker-release`:
   - Logs in to DockerHub
   - Uses Docker Build Cloud (`mitre/mitre-builder`) for native multi-arch builds
   - Builds `linux/amd64` and `linux/arm64` images
   - Pushes `mitre/vulcan:v2.3.2` and `mitre/vulcan:latest` to DockerHub
   - Generates SBOM (SPDX format) and submits to GitHub dependency graph

### 5. Verify the release

1. Check [Actions](https://github.com/mitre/vulcan/actions) — `release.yml` and `ci.yml` runs should both be green
2. Check [Releases](https://github.com/mitre/vulcan/releases) — new release should exist with changelog populated
3. Check [DockerHub](https://hub.docker.com/r/mitre/vulcan/tags) — new version tag and `latest` should be present
4. Pull and smoke-test the image:

```bash
docker pull mitre/vulcan:v2.3.2

# Quick sanity check — should print the version and exit
docker run --rm mitre/vulcan:v2.3.2 bundle exec rails runner "puts Vulcan::VERSION"
```

## How Version Files Stay in Sync

| File | How it's updated |
|------|-----------------|
| `VERSION` | **You update this manually** before tagging |
| `package.json` | Run `bundle exec rake version:sync` after editing VERSION |
| `lib/vulcan/version.rb` | Reads VERSION at load time — no editing needed |
| `CHANGELOG.md` | git-cliff commits this automatically after each tag push |

`lib/vulcan/version.rb` strips the `v` prefix from VERSION so it can be used as a clean Ruby constant (`Vulcan::VERSION # => "2.3.2"`).

## Hotfix / Emergency Release

For a critical fix that must go out without waiting for pending work:

```bash
# Start from the last release tag
git checkout v2.3.1
git checkout -b hotfix/v2.3.2

# Make the fix
# ... edit files ...
git add <files>
git commit -m "fix: correct critical issue in rule export"

# Update VERSION
echo "v2.3.2" > VERSION
bundle exec rake version:sync
git add VERSION package.json
git commit -m "chore: bump version to v2.3.2"

# Push the branch and open a PR to master
git push origin hotfix/v2.3.2
# Merge the PR to master after review

# Then tag from master
git checkout master
git pull origin master
git tag v2.3.2
git push origin v2.3.2
```

This follows the same tag-triggered flow. There is no separate hotfix workflow.

## Docker Image Details

- **Registry**: [hub.docker.com/r/mitre/vulcan](https://hub.docker.com/r/mitre/vulcan)
- **Architectures**: `linux/amd64`, `linux/arm64` (built natively via Docker Build Cloud)
- **Tags**: `v2.3.2` (immutable) and `latest` (updated on each release)
- **Base**: Ruby 3.4.9 on Debian Bookworm with jemalloc

## Troubleshooting

**The release.yml run failed — no GitHub Release was created.**

Check the Actions log. Common causes:
- Malformed `cliff.toml` (TOML syntax error)
- `GITHUB_TOKEN` permissions — the workflow requires `contents: write`

If the release was not created, delete the tag, fix the issue, and re-push:

```bash
git tag -d v2.3.2
git push origin :refs/tags/v2.3.2
# fix the issue, then:
git tag v2.3.2
git push origin v2.3.2
```

**The GitHub Release was created but Docker images were not pushed.**

The `docker-release` job in `ci.yml` only runs when a release is published. If tests fail, Docker is skipped. Fix the test failures on master, then:

- You cannot re-trigger docker-release automatically without publishing a new release
- Either publish a patch release with the fix, or manually publish the Docker image using the Dockerfile

**`CHANGELOG.md` has a merge conflict after the bot commit.**

git-cliff pushes to master directly from the tag workflow. If another commit landed on master simultaneously, the push may fail. The changelog content is still in the GitHub Release body. Re-run `git-cliff` locally to regenerate:

```bash
# Install git-cliff if needed
brew install git-cliff

# Regenerate full changelog
git-cliff --config cliff.toml --output CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs: regenerate CHANGELOG.md"
git push origin master
```
