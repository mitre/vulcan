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

- Building `linux/amd64` + `linux/arm64` images and pushing `mitre/vulcan:<x.y.z>` and `mitre/vulcan:release-latest`. This takes about an hour on the free default driver (see [The two build drivers](#the-two-build-drivers)).
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
| `release.yml` | `release: published` only | Verifies the tag, then publishes the stable image and the Iron Bank merge request. |
| `mainline.yml` | push to `master`, `workflow_dispatch` | Publishes the bleeding-edge image (`<git-sha>` + `latest`) and a merge request against the separate `vulcan-mainline` repo1 project. Builds on the free emulated driver (~65 min), so routine master pushes never spend shared Build Cloud minutes; superseded pushes are cancelled. |
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
| `vars.RELEASE_BUILDER` | Optional, **repository** variable. Set to `cloud` to make the next release build on Docker Build Cloud. Leave unset for the free default. |

### The two build drivers

The image compiles Ruby, jemalloc and YJIT from source for `linux/amd64` and `linux/arm64`. There are two ways to build it.

| Driver | How long | Cost | When |
|--------|----------|------|------|
| `emulated` | **~65 min** (last five mainline builds: 62m13s, 62m35s, 63m15s, 63m43s, 64m10s) | **Free.** GitHub-hosted standard runners cost nothing for public repositories. | **The default, everywhere** — releases and every push to `master`. |
| `cloud` | **2-10 min** (2m35s measured; slowest on record 10m26s) | **Spends Docker Build Cloud minutes from a single small monthly pot shared by the entire MITRE organization.** Vulcan is one team of several drawing on it. | **Opt-in**, when a release needs to be fast. |

So a normal release takes about an hour and costs nothing. That is the deliberate trade: the shared minute pot is small, and a release that is slow but free and reliable beats one that is fast and competes with other teams for a scarce resource.

::: tip Emulation is slow, not broken
This is worth stating plainly because the 2.4.x failures made it look otherwise. Emulated multi-arch builds of this image succeed consistently — five consecutive `mainline.yml` runs completed in 62–64 minutes and each pushed a working two-architecture image. The 2.4.0, 2.4.1 and 2.4.2 releases were cancelled because the emulated path ran under a budget sized for Build Cloud (20 minutes, later 45) rather than for itself. The budget is now derived from the driver, so that mismatch cannot be expressed.
:::

#### Asking for Build Cloud on a release

Set a repository variable before you publish. The publish job prints which driver it used and writes it to the run summary, so the path taken is always visible.

1. Settings → Secrets and variables → Actions → Variables
2. Set the repository variable **`RELEASE_BUILDER`** to `cloud`
3. Publish the release as usual
4. **Unset it afterwards**, or every subsequent release will quietly spend shared minutes

The variable is read when the job starts, so it also applies to a re-run of a failed publish — set it, then re-run.

::: warning The first emulated release is a measurement
No `release: published` run has ever completed an emulated build, because none was ever given enough time. The budget is **120 minutes**, set from mainline's 62–64 minute builds plus headroom for the SBOM and repo1 steps. Record the actual publish-job duration of the first emulated release and tighten the budget in `docker-publish.yml` to roughly 1.5× it. GitHub's hard job ceiling is 6 hours, so erring high costs nothing but a slower failure signal.
:::

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
                  spec/config/version_spec.rb
```

### 5. Write the changelog entry

`CHANGELOG.md` is hand-authored. Rename the `## [Unreleased]` heading to a dated section for this release, keeping the [Keep a Changelog](https://keepachangelog.com) sections already in use (`Added`, `Fixed`, `Changed`, plus `Behavior changes` when there are any), and leave a fresh empty `## [Unreleased]` above it:

```markdown
## [Unreleased]

## [v2.5.0] - 2026-11-30

### Added

- **Short bold summary.** Then the detail a self-hoster needs.
```

Nothing enforces this, so it is on you: an unwritten changelog will not fail CI.

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

Open a PR to `master`, get it reviewed, and merge it. Branch protection does the work here: `ci-gate` is a required check and `strict` is enabled, so the PR must be rebased onto current `master` and green before it can merge. `release.yml` does not re-check CI — it trusts branch protection rather than re-proving it.

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
- **publish** — multi-arch build and push, SBOM submission, per-architecture digest resolution, Iron Bank merge request. The job prints the driver it used and writes it to the run summary.

Expect **about 65 minutes** on the default `emulated` driver, with a 120-minute budget. If you opted into `cloud`, expect 2–10 minutes against a 25-minute budget. A `cancelled` conclusion means the budget was exceeded — see [Troubleshooting](#troubleshooting).

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
- **Architectures**: `linux/amd64` and `linux/arm64` — built under QEMU on the runner by default, or on native Build Cloud machines when opted in. Both produce the same two-architecture manifest list, and the publish fails if either architecture is missing from the registry afterwards.
- **Base**: Red Hat UBI 9 Minimal, with Ruby and jemalloc compiled from source and YJIT enabled. The exact Ruby and Node versions come from `.ruby-version` and `.nvmrc` via `docker-bake.hcl`; `spec/config/toolchain_version_consistency_spec.rb` keeps them aligned.
- **Iron Bank** currently pulls the amd64 image only, even though both architectures are published and both digests are recorded in the manifest.

::: tip Open question: how often should `master` be built?
`mainline.yml` builds a full two-architecture image on **every** push to `master`, which is about an hour of runner time each (free, but not nothing — it occupies an organization concurrency slot, and superseded pushes are cancelled rather than queued). For a bleeding-edge tag that is arguably more than it needs.

**The current per-push cadence stands.** The options below are recorded as input to that discussion, not as pending work.

One option is to move `mainline.yml` from `push:` to a **daily `schedule:`** plus its existing manual dispatch. That would cut the cost by roughly 90% and keep both the multi-architecture `latest` image and the repo1 mainline feed exactly as they are. The tradeoff is that `mitre/vulcan:<git-sha>` images would exist only for the commits that happen to be `HEAD` when the schedule fires, rather than for every commit — so anything that pins a specific `<git-sha>` image would no longer be able to.

Two alternatives were considered and are **not** recommended: building `master` as amd64-only would drop `latest` to a single architecture (breaking it for Apple Silicon developers) and would break the repo1 mainline hardening manifest, which requires both per-architecture digests. Native per-architecture runners (`ubuntu-24.04-arm` plus a manifest merge) would remove the emulation cost entirely and are free for public repositories, but are unvalidated here and no longer urgent now that the emulated path is correctly budgeted.

Any of these changes a published artifact contract, so the cadence is a team decision and is deliberately not folded into a release fix.
:::

## Troubleshooting

### The verify job failed

The error annotation names the problem:

| Message | Fix |
|---------|-----|
| `… is not a vMAJOR.MINOR.PATCH release tag` | Delete the release and the tag; re-publish with a `vX.Y.Z` tag. |
| `VERSION at v2.5.0 reads '…'` | The tag points at the wrong commit. Land the bump commit on `master` first, delete the tag, and re-publish against it. |
| `… is not on master` | The release target was a branch or fork commit. Re-publish targeting `master`. |


### The publish failed or was cancelled — re-run it

The GitHub Release and its tag already exist, so do **not** cut a new version and do not delete and re-publish the release.

Open the failed run and use **Re-run failed jobs** (or **Re-run all jobs**). GitHub replays the original `release` event, so the tag resolves exactly as it did the first time and the verify job runs again — there is no second way to name the tag, and therefore no way for a re-run to publish something the first attempt would have refused.

There is deliberately no `workflow_dispatch` on this workflow. A dispatch form would mean a second source for the tag and a second source for the driver, either of which could disagree with the release actually being published.

If the run is old enough that GitHub no longer offers a re-run, publish a new patch release rather than trying to recreate the event.

### The release is taking an hour

That is normal on the free default driver — emulated builds of this image run 62–64 minutes. See [The two build drivers](#the-two-build-drivers). If you need it faster, cancel the run, set `vars.RELEASE_BUILDER` to `cloud`, and re-run the cancelled run.

### Build Cloud is unavailable or out of minutes

Only relevant if you opted in. If the "Set up Docker Buildx (Docker Build Cloud)" step fails, it is the endpoint, the organization's subscription, or an exhausted monthly pot. The step fails within a minute rather than degrading to something slower — deliberately, because this job is then budgeted at 25 minutes and an emulated build needs about 65. A slow driver running under a fast driver's budget is exactly how 2.4.0, 2.4.1 and 2.4.2 were lost.

**Fix:** unset `vars.RELEASE_BUILDER` and re-run. The free path applies, with its own 120-minute budget. Do not raise a timeout by hand — the budget follows the driver.

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
| `package.json` | `bundle exec rake version:sync` | `version_spec.rb` |
| `lib/vulcan/version.rb` | Reads `VERSION` at load, strips the `v`. No edit needed. | `version_spec.rb` |
| `CHANGELOG.md` | **You write it.** | Not enforced — check it yourself |
| `docs/site/index.md` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/site/release-notes/index.md` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/.vitepress/config.mjs` | **You edit it.** | `docs_version_consistency_spec.rb` |
| `docs/site/release-notes/v<version>.md` | **You create it.** | `docs_version_consistency_spec.rb` |
