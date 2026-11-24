# Vulcan Release Process

## Overview

A Vulcan release is **two human steps and one automated step**:

1. **You** land a version-bump pull request on `master` (version files, changelog, release-notes page) and wait for CI to go green.
2. **You** publish a GitHub Release in the web UI. Publishing creates the tag.
3. **`release.yml`** reacts to the `release: published` event: it verifies the tag is releasable, builds the multi-arch image, pushes it to DockerHub, submits an SBOM, and opens a merge request against Vulcan's Iron Bank project on repo1.

That is the whole process. There is nothing else, and nothing happens before step 2.

::: warning Pushing a tag by itself does nothing
No workflow has a `push: tags:` trigger. `git push origin v2.5.0` fires zero workflows. The tag is a *consequence* of publishing the release, not the thing that starts it.
:::

### What is automated

- Building `linux/amd64` + `linux/arm64` images and pushing `mitre/vulcan:<x.y.z>` and `mitre/vulcan:release-latest`.
- Checking, before the build, that the tag is semver, that `VERSION` at the tagged commit equals the tag, that the commit is on `master`, and that `ci.yml` concluded success for that exact commit.
- SBOM generation and submission to the GitHub dependency graph.
- Opening the Iron Bank merge request on repo1 with both per-architecture digests.

### What is **not** automated

- Choosing the version.
- Editing any version file. No bot touches `VERSION`, `package.json`, the docs, or `CHANGELOG.md`.
- Writing `CHANGELOG.md` entries or the release-notes page. Both are hand-authored prose. No workflow invokes git-cliff; `cliff.toml` is a local drafting aid only (see [Drafting the changelog](#drafting-the-changelog)).
- Creating the GitHub Release or its body text.
- Merging the Iron Bank merge request. A human on the repo1 side does that.

## CI/CD workflow files

| File | Trigger | Purpose |
|------|---------|---------|
| `ci.yml` | push to `master`, pull requests | Lint, security scans, frontend + backend test shards, SonarCloud. **Has no release trigger and does not build images.** |
| `release.yml` | `release: published`, `workflow_dispatch` | Verifies the tag, then publishes the stable image and the Iron Bank merge request. |
| `mainline.yml` | push to `master`, `workflow_dispatch` | Publishes the bleeding-edge image (`<git-sha>` + `latest`) and a merge request against the separate `vulcan-mainline` repo1 project. |
| `docker-publish.yml` | `workflow_call` only | The shared build-and-push implementation that `release.yml` and `mainline.yml` both call. Not runnable on its own. |
| `docs.yml` | push to `master` touching `docs/`, pull requests, `workflow_dispatch` | Builds and deploys the VitePress site to GitHub Pages. |
| `dependabot.yml` | `pull_request_target` | Auto-approves and merges Dependabot pull requests. |

## Prerequisites

**Access**

- Write access to `mitre/vulcan` (to merge the bump PR and publish the Release).

**Organization secrets and variables** — these live at the MITRE organization level, not on the repository, so they will not appear under the repository's own Actions settings:

| Name | Used for |
|------|----------|
| `vars.DOCKER_USER` | DockerHub login |
| `secrets.DOCKER_PAT` | DockerHub login |
| `secrets.SAF_IRONBANK_REPO1_PAT` | repo1 merge request |
| `secrets.SAF_IRONBANK_REPO1_USERNAME` | repo1 merge request |
| `vars.DOCKER_BUILD_CLOUD_ENDPOINT` | Optional. Overrides the Docker Build Cloud builder endpoint; defaults to `mitre/mitre-builder`. |

**Docker Build Cloud.** The image compiles Ruby and jemalloc from source for two architectures. On a GitHub-hosted runner with QEMU emulation that takes longer than any reasonable job budget; it is the reason the 2.4.0, 2.4.1 and 2.4.2 publishes were all cancelled on timeout and why no `2.4.0` or `2.4.2` image exists on DockerHub. The publish therefore builds on Docker Build Cloud unconditionally, which takes **2-4 minutes**. If the MITRE Build Cloud subscription lapses, the buildx setup step fails within a minute — see [Troubleshooting](#build-cloud-is-unavailable).

## Semver guidance

- **Patch** (`v2.4.x`) — bug fixes, dependency updates, maintenance.
- **Minor** (`v2.x.0`) — new user-facing features.
- **Major** (`vX.0.0`) — breaking changes. Discuss with the team first.

## Step-by-step release

The worked example below releases **v2.5.0**. Substitute your version everywhere.

### 1. Confirm master is ready

```bash
git checkout master
git pull origin master
```

Check that CI is green on `master` in the [Actions tab](https://github.com/mitre/vulcan/actions). A release cannot be published from a red commit — `release.yml` refuses.

### 2. Create the version-bump branch

```bash
git checkout -b release/v2.5.0
```

### 3. Bump the version files

`VERSION` is the single source of truth. Edit it, then sync the derived file:

```bash
echo "v2.5.0" > VERSION
bundle exec rake version:sync          # rewrites package.json
```

`lib/vulcan/version.rb` reads `VERSION` at load time and strips the `v` prefix, so `Vulcan::VERSION == "2.5.0"`. **It needs no edit.**

### 4. Update the four docs version surfaces

`spec/config/docs_version_consistency_spec.rb` compares every "latest release" surface in the docs against `Vulcan::VERSION`. Bumping `VERSION` without these four edits turns four examples red, so CI fails on your bump commit.

| # | File | What to change |
|---|------|----------------|
| 1 | `docs/site/index.md` | The `::: info Current Version` block (around line 92): the `**v2.5.0**` version, the release month, the one-line summary, and the `[View Release Notes →](/release-notes/v2.5.0)` link. |
| 2 | `docs/site/release-notes/index.md` | Move the old entry from `## Current Release` down into `## Previous Releases`, and add the new `- **[v2.5.0](v2.5.0)** — …` bullet under `## Current Release`. |
| 3 | `docs/.vitepress/config.mjs` | In the version nav dropdown (around line 219): change `text: "v2.4.2"` to `text: "v2.5.0"`, repoint `{ text: "Release Notes", link: "/release-notes/v2.5.0" }`, and insert the previous version as its own item below it. |
| 4 | `docs/site/release-notes/v2.5.0.md` | **Create this page.** The spec asserts `docs/site/release-notes/v<version>.md` exists. Copy the structure of the previous release's page. |

Verify before pushing:

```bash
bundle exec rspec spec/config/docs_version_consistency_spec.rb \
                  spec/config/release_infrastructure_spec.rb
```

### 5. Write the changelog entry

`CHANGELOG.md` is hand-authored. Rename the `## [Unreleased]` heading to a dated section for this release, keeping the [Keep a Changelog](https://keepachangelog.com) sections already in use (`Added`, `Fixed`, `Changed`, plus `Behavior changes` when there are any), and leave a fresh empty `## [Unreleased]` above it:

```markdown
## [Unreleased]

## [v2.5.0] - 2026-11-30

### Added

- **Short bold summary.** Then the detail a self-hoster needs.
```

`spec/config/release_infrastructure_spec.rb` asserts a `## [v<version>]` section exists for the current version, so an unwritten changelog fails CI.

::: tip `[Unreleased]` is often already populated
Fix and feature branches add their own bullets under `## [Unreleased]` as they merge, so do not expect it to be empty. Your job at release time is to **rename that heading** to `## [v2.5.0] - <date>`, review and edit the entries already there, add anything missing, and open a fresh empty `## [Unreleased]` above it. Do not delete entries other people wrote.
:::

The release-notes page from step 4 is the user-facing version of the same content: more context, upgrade warnings, and anything a self-hoster must do before upgrading.

#### Drafting the changelog

`cliff.toml` configures [git-cliff](https://git-cliff.org) to group conventional commits into Keep a Changelog sections. **No workflow invokes it** — it is there so you can draft locally:

```bash
brew install git-cliff
git cliff --unreleased --strip header
```

Treat the output as raw material. Bare commit subjects are not release notes; rewrite them into prose that explains the user-visible change. Conventional commit prefixes (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`) make that draft useful, which is reason enough to keep using them.

### 6. Open the bump PR and merge it

```bash
git add VERSION package.json CHANGELOG.md \
        docs/site/index.md \
        docs/site/release-notes/index.md \
        docs/site/release-notes/v2.5.0.md \
        docs/.vitepress/config.mjs
git commit -s -m "chore: bump version to v2.5.0"
git push origin release/v2.5.0
```

Open a PR to `master`, get it reviewed, and merge it. **Wait for `ci.yml` to finish green on the resulting `master` commit.** This is not optional politeness: `release.yml` queries that run's conclusion and refuses to publish without it.

### 7. Publish the GitHub Release

Go to [Releases → Draft a new release](https://github.com/mitre/vulcan/releases/new).

| Field | Value |
|-------|-------|
| **Choose a tag** | Type `v2.5.0` and select **Create new tag: v2.5.0 on publish** |
| **Target** | `master` — specifically the bump commit from step 6 |
| **Title** | `v2.5.0` |
| **Description** | The release-notes content, or a summary plus a link to `/release-notes/v2.5.0` |

Click **Publish release**. Publishing creates the tag and fires `release.yml`.

::: tip Ordering matters
The bump commit must be on `master` before you publish. `release.yml` compares `VERSION` at the tagged commit to the tag name, so publishing a release whose target predates the bump fails the verify job rather than pushing a mislabelled image. If you prefer to create the tag yourself with `git tag`, do it after the bump commit lands and then select the existing tag here — but the push alone still publishes nothing.
:::

### 8. Watch the run

`release.yml` runs two jobs:

- **Verify the tag is releasable** (seconds) — semver tag, `VERSION` matches the tag, commit is an ancestor of `master`, `ci.yml` succeeded for that commit.
- **publish** (2-4 minutes) — Build Cloud multi-arch build and push, SBOM submission, per-architecture digest resolution, Iron Bank merge request.

Expect the whole run to finish in **under 10 minutes**. If it is still running at 25 minutes it will be cancelled by the job timeout; see [Troubleshooting](#troubleshooting).

## Verifying the release worked

Do all four. The 2.4.2 release was marked published on GitHub while no image was ever pushed, and nobody noticed for three months because nobody checked the registry.

**1. The workflow run is green.** Both jobs in [Actions → Release](https://github.com/mitre/vulcan/actions/workflows/release.yml). A `cancelled` conclusion means the timeout fired — the release is **not** complete.

**2. The image tag exists on DockerHub, with both architectures.** Check [hub.docker.com/r/mitre/vulcan/tags](https://hub.docker.com/r/mitre/vulcan/tags), or from a shell:

```bash
docker manifest inspect mitre/vulcan:2.5.0 \
  | grep -o '"architecture": "[^"]*"' | sort -u
# expect: "architecture": "amd64"  and  "architecture": "arm64"
```

Note the tag has **no `v` prefix**. See [Image tags](#image-tags).

**3. `release-latest` moved to the new release.** The digests must match:

```bash
docker buildx imagetools inspect mitre/vulcan:2.5.0        --format '{{.Manifest.Digest}}'
docker buildx imagetools inspect mitre/vulcan:release-latest --format '{{.Manifest.Digest}}'
```

**4. Smoke-test the image.**

```bash
docker pull mitre/vulcan:2.5.0
docker run --rm mitre/vulcan:2.5.0 bundle exec rails runner "puts Vulcan::VERSION"
# expect: 2.5.0
```

**5. The Iron Bank merge request opened.** Confirm the "Open the Iron Bank merge request" step is green, then check the [Vulcan project on repo1](https://repo1.dso.mil/dsop/mitre/security-automation-framework/vulcan) (project `17073`) for a new merge request from `Automated Vulcan Release`. It should update `hardening_manifest.yaml` so `tags[0]`, the `org.opencontainers.image.version` label, and both `resources` entries point at `2.5.0` and at the amd64/arm64 digests by `sha256:`. A human on the repo1 side reviews and merges it; the release is not "on Iron Bank" until they do.

## Image tags

| Tag | Published by | Meaning |
|-----|--------------|---------|
| `mitre/vulcan:2.5.0` | `release.yml` | Immutable stable release. **No `v` prefix.** |
| `mitre/vulcan:release-latest` | `release.yml` | Moving pointer to the most recent stable release. **Use this, or a pinned version, in production.** |
| `mitre/vulcan:<git-sha>` | `mainline.yml` | A specific `master` commit. |
| `mitre/vulcan:latest` | `mainline.yml` | Bleeding-edge `master`. **Not a release.** Only for trying unreleased code. |

::: danger The image tag is not the git tag
The git tag is `v2.5.0`; the image tag is `2.5.0`. `release.yml` strips the prefix (`version=${raw#v}`), so **`mitre/vulcan:v2.5.0` does not exist and never has.** Releases up to v2.2.1 used v-prefixed image tags; everything from 2.3.3 onward does not. `docker pull` against a v-prefixed tag will tell you the image is missing when it is actually there.
:::

- **Registry**: [hub.docker.com/r/mitre/vulcan](https://hub.docker.com/r/mitre/vulcan)
- **Architectures**: `linux/amd64` and `linux/arm64`, each built on a native Build Cloud machine
- **Base**: Red Hat UBI 9 Minimal, with Ruby and jemalloc compiled from source and YJIT enabled. The exact Ruby and Node versions come from `.ruby-version` and `.nvmrc` via `docker-bake.hcl`; `spec/config/toolchain_version_consistency_spec.rb` keeps them aligned.
- **Iron Bank** currently pulls the amd64 image only, even though both architectures are published and both digests are recorded in the manifest.

## Troubleshooting

### The verify job failed

The error annotation names the problem:

| Message | Fix |
|---------|-----|
| `… is not a vMAJOR.MINOR.PATCH release tag` | Delete the release and the tag; re-publish with a `vX.Y.Z` tag. |
| `VERSION at v2.5.0 reads '…'` | The tag points at the wrong commit. Land the bump commit on `master` first, delete the tag, and re-publish against it. |
| `… is not on master` | The release target was a branch or fork commit. Re-publish targeting `master`. |
| `No completed push-event CI run found for …` | `ci.yml` has not finished for that commit. Wait for it, then re-run `release.yml` (below). |
| `CI for … concluded 'failure'` | Fix `master`, re-run `ci.yml` to green on that same commit, then re-run `release.yml`. Do not bypass this. |

### The publish failed or was cancelled — re-run it

The GitHub Release and its tag already exist, so do **not** cut a new version. Re-dispatch the workflow against the existing tag:

1. [Actions → Release](https://github.com/mitre/vulcan/actions/workflows/release.yml) → **Run workflow**
2. Set **Use workflow from** to the tag (`v2.5.0`), or leave the default branch and enter `v2.5.0` in the **tag** input
3. **Run workflow**

The verify job runs again, so this is safe: it cannot publish something the `release: published` path would have refused.

### Build Cloud is unavailable

If the "Set up Docker Buildx (Docker Build Cloud)" step fails, the builder endpoint or the organization's Build Cloud subscription is the problem. Check `vars.DOCKER_BUILD_CLOUD_ENDPOINT` (or the `mitre/mitre-builder` default) and the subscription status before anything else.

There is deliberately **no emulated fallback**. A silently-selected QEMU path is what broke three consecutive releases: it cannot finish inside a sane budget, so it consumed the whole job timeout and then cancelled. If Build Cloud is genuinely gone and a release must ship, that is a decision to make explicitly — an emulated multi-arch build of this image is roughly a 45-90 minute job and needs `timeout_minutes` raised to match, which is a reviewed change to `docker-publish.yml`, not something to improvise during a release.

### The image tag is missing from DockerHub but the run is green

Registry propagation can lag by seconds; the digest-resolution step already retries for 25 seconds. If a tag is still absent minutes later, re-run the workflow — pushing the same tag again is idempotent.

### The Iron Bank step failed

The image is already on DockerHub at this point; only the repo1 merge request is missing. Re-running the whole workflow is the simplest fix and is safe. If the step fails on authentication, the `SAF_IRONBANK_REPO1_PAT` / `SAF_IRONBANK_REPO1_USERNAME` organization secrets need attention — repo1 personal access tokens expire.

## Hotfix / emergency release

Same process, shorter path. The release still comes from `master`.

```bash
git checkout -b hotfix/v2.5.1 master

# make the fix
git add <files>
git commit -s -m "fix: correct critical issue in rule export"

# bump, as in steps 3-5 above
echo "v2.5.1" > VERSION
bundle exec rake version:sync
# ... edit the four docs surfaces, CHANGELOG.md, and
# ... create docs/site/release-notes/v2.5.1.md

git add VERSION package.json CHANGELOG.md docs/
git commit -s -m "chore: bump version to v2.5.1"
git push origin hotfix/v2.5.1
```

Open the PR, merge to `master`, wait for green CI, then publish the release as in step 7. There is no separate hotfix workflow and no way to skip the CI gate.

## How version files stay in sync

| File | How it is updated | Enforced by |
|------|-------------------|-------------|
| `VERSION` | **You edit it.** Single source of truth, `v`-prefixed. | — |
| `package.json` | `bundle exec rake version:sync` | `release_infrastructure_spec.rb` |
| `lib/vulcan/version.rb` | Reads `VERSION` at load, strips the `v`. No edit needed. | `release_infrastructure_spec.rb` |
| `CHANGELOG.md` | **You write it.** | `release_infrastructure_spec.rb` |
| `docs/site/index.md` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/site/release-notes/index.md` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/.vitepress/config.mjs` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/site/release-notes/v<version>.md` | **You create it.** | `docs_version_consistency_spec.rb` |
