# Create and Publish a Vulcan Release

## Overview

Vulcan uses a **release-first** model:

1. A draft release is created manually via the **Create Release Draft** workflow
2. You review and edit the draft (notes, version tag)
3. Publishing the draft triggers CI to build and push multi-arch Docker images

Docker images are **only built and pushed on release publish** — not on every push to master.

## Prerequisites

- Push access to the Vulcan repository
- Familiarity with [Semantic Versioning](https://semver.org/)

## CI/CD Workflow Files

| File | Purpose |
|------|---------|
| `ci.yml` | Lint, test (frontend + backend shards), SonarCloud, Docker release |
| `release.yml` | Auto-create draft releases (biweekly cron + manual trigger) |
| `docs.yml` | Deploy VitePress documentation to GitHub Pages |
| `dependabot.yml` | Auto-approve and merge Dependabot PRs |

## Step 1: Review the Draft Release

Create a draft release by going to **Actions** → **Create Release Draft** → **Run workflow**. The workflow auto-bumps the patch version from the previous release (e.g., v2.3.1 → v2.3.2).

1. Navigate to the Vulcan repository → **Releases**
2. Click the edit button on the new draft release (or click **Draft a new release** to create one manually)
3. Click **Generate release notes** to auto-generate notes from merged PRs
4. Review and categorize the notes
5. Adjust the version tag following semver:
   - **Patch** (v2.3.x): dependency updates, bug fixes
   - **Minor** (v2.x.0): new features
   - **Major** (vX.0.0): breaking changes

> Discuss major/minor version bumps with the team before proceeding.

## Step 2: Update Version Files

On your local environment:

```bash
git checkout master
git pull origin master
```

Update these files with the new version number:

1. `VERSION`
2. `package.json` — the `version` field
3. `README.md` — the Latest Release section
4. `CHANGELOG.md` — generate with:

   ```bash
   gem install github_changelog_generator  # if not installed
   # Edit .github_changelog_generator: set future-release to new version
   github_changelog_generator --token <your-github-token>
   ```

Commit and push:

```bash
git add VERSION package.json README.md CHANGELOG.md .github_changelog_generator
git commit -m "v2.3.2"
git push
```

## Step 3: Verify CI Passes

1. Go to **Actions** → **CI** workflow
2. Confirm all jobs pass on master: lint, frontend, backend (4 shards), sonarcloud
3. If any job fails, fix the issue and push before proceeding

> **Note**: The `docker-release` job only runs when a release is published — it will not appear on regular pushes to master.

## Step 4: Verify Staging (if applicable)

If using Heroku staging:

1. Check the [staging deployment log](https://github.com/mitre/vulcan/deployments/activity_log?environment=mitre-vulcan-staging)
2. Test the app on staging
3. Address any issues before publishing

## Step 5: Publish the Release

1. Go back to the draft release and click **Publish release**
2. This triggers the `ci.yml` workflow with the `release` event, which:
   - Runs all lint and test jobs
   - Builds multi-arch Docker images (linux/amd64 + linux/arm64) via [Docker Build Cloud](https://docs.docker.com/build/cloud/)
   - Pushes to DockerHub as `mitre/vulcan:<version>` and `mitre/vulcan:latest`
   - Generates an SBOM (Software Bill of Materials) and submits to GitHub dependency graph
3. Verify the Docker release job completes successfully in the Actions tab

## Step 6: Verify the Docker Image

```bash
# Pull the newly released image
docker pull mitre/vulcan:v2.3.2

# Or pull latest
docker pull mitre/vulcan:latest

# Test locally
./setup-docker-secrets.sh  # if not already done
# In docker-compose.prod.yml, use: image: mitre/vulcan:v2.3.2
docker compose -f docker-compose.prod.yml up
```

## Docker Image Details

- **Registry**: [hub.docker.com/r/mitre/vulcan](https://hub.docker.com/r/mitre/vulcan)
- **Architectures**: linux/amd64, linux/arm64 (built natively via Docker Build Cloud)
- **Tags**: `v2.3.2` (immutable semver) + `latest` (points to newest release)
- **Base**: Ruby 3.4.8 on Debian Bookworm with jemalloc
