# Release Process

Modern, automated release process for Vulcan using semantic versioning, rails_app_version gem, and GitHub Actions.

## Overview

Vulcan uses **tag-based automated releases**:
1. Update VERSION file
2. Push a git tag
3. GitHub Actions handles everything else automatically

No manual release creation needed!

## Version Management

### Single Source of Truth: VERSION File

The `VERSION` file in the project root is the only place you edit the version:

```
2.3.0
```

Everything else is derived automatically:
- `Rails.application.version` (via rails_app_version gem)
- `package.json` (synced)
- `/status` endpoint JSON
- Docker image tags
- HTTP response headers (X-App-Version)

### Accessing Version in Code

```ruby
# Ruby code
Rails.application.version.to_s  # => "2.3.0"
Rails.application.version.major # => 2
Rails.application.version.minor # => 3
Rails.application.version.patch # => 0

# In controllers/views
<%= Rails.application.version %>
```

## Creating a Release

### Step 1: Prepare the Release

```bash
# 1. Ensure you're on master and up to date
git checkout master
git pull origin master

# 2. Run full test suite
bundle exec rspec
bundle exec rubocop
bundle exec brakeman

# 3. Update VERSION file
echo "2.3.0" > VERSION

# 4. Sync package.json (if needed)
VERSION=$(cat VERSION | tr -d '\n')
jq --arg v "$VERSION" '.version = $v' package.json > tmp.json && mv -f tmp.json package.json

# 5. Update CHANGELOG.md
# Add section for this release with features, fixes, etc.
# See "CHANGELOG Format" section below

# 6. Commit version bump
git add VERSION package.json CHANGELOG.md
git commit -m "chore: bump version to $VERSION

Authored by: Aaron Lippold<lippold@gmail.com>"
git push origin master
```

### Step 2: Create and Push Tag

```bash
# Create annotated tag
git tag -a v2.3.0 -m "Release v2.3.0

- ARM64/Apple Silicon support
- Configurable SSL enforcement
- Health check endpoints
- Email validation improvements"

# Push tag (triggers automation)
git push origin v2.3.0
```

### Step 3: GitHub Actions Takes Over

Once the tag is pushed, `.github/workflows/release.yml` automatically:

1. ✅ **Validates** - Checks tag format and VERSION file consistency
2. ✅ **Tests** - Runs RSpec, RuboCop, Brakeman
3. ✅ **Creates Release** - GitHub release with generated notes
4. ✅ **Builds Docker** - Multi-platform images (amd64 + arm64)
5. ✅ **Pushes to Docker Hub** - Tags: `v2.3.0` and `latest`

**Monitor progress:** https://github.com/mitre/vulcan/actions

## Semantic Versioning

Follow [SemVer 2.0.0](https://semver.org/):

### Patch Release (2.3.0 → 2.3.1)
- Bug fixes
- Security patches
- Documentation updates
- No new features

### Minor Release (2.3.0 → 2.4.0)
- New features (backwards-compatible)
- New endpoints
- New configuration options
- Deprecations with warnings

### Major Release (2.3.0 → 3.0.0)
- Breaking changes
- Removed deprecated features
- Database schema breaking changes
- Major architecture changes

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [2.3.0] - 2025-10-21

### Added
- ARM64/Apple Silicon Docker image support
- FORCE_SSL environment variable for flexible SSL configuration
- Health check endpoints: /up, /health_check/database, /status
- Production email validation (blocks @example.com domains)
- User email validation (blocks disposable email providers)
- rails_app_version gem for centralized version management

### Changed
- PostgreSQL upgraded to 16-alpine in docker-compose
- Bundler upgraded to 2.7.2
- Health check gem added for Kubernetes readiness probes

### Fixed
- Email configuration validation prevents spam filter issues
- SMTP settings properly validated in production

### Security
- Enhanced email validation
- Disposable email blocking for user registration
```

## Pre-Release Checklist

Before pushing a tag:

- [ ] All tests passing: `bundle exec rspec`
- [ ] No linting issues: `bundle exec rubocop`
- [ ] No security issues: `bundle exec brakeman`
- [ ] VERSION file updated
- [ ] package.json synced
- [ ] CHANGELOG.md updated
- [ ] Documentation updated
- [ ] Local Docker build tested
- [ ] Changes committed to master
- [ ] Ready to tag

## Hotfix Process

For urgent production fixes:

```bash
# 1. Branch from release tag
git checkout -b hotfix/2.3.1 v2.3.0

# 2. Fix the issue
# ... make changes ...

# 3. Test thoroughly
bundle exec rspec

# 4. Update version (patch bump)
echo "2.3.1" > VERSION

# 5. Commit
git add .
git commit -m "fix: critical security issue

Authored by: Aaron Lippold<lippold@gmail.com>"

# 6. Tag and push
git tag -a v2.3.1 -m "Hotfix v2.3.1"
git push origin hotfix/2.3.1
git push origin v2.3.1

# 7. Merge back to master
git checkout master
git merge hotfix/2.3.1
git push origin master
```

## Rolling Back

If a release has critical issues:

```bash
# 1. Delete tag
git tag -d v2.3.0
git push origin :refs/tags/v2.3.0

# 2. Delete GitHub release (web UI or CLI)
gh release delete v2.3.0 --yes

# 3. Delete Docker images (contact Docker Hub admin)
# Or just push a new patch release

# 4. Create fixed version
echo "2.3.1" > VERSION
# ... fix issues ...
git tag -a v2.3.1 -m "Release v2.3.1 (fixes v2.3.0)"
git push origin v2.3.1
```

## Verification

After release automation completes:

### 1. Check GitHub Release
```bash
# Via web
https://github.com/mitre/vulcan/releases/tag/v2.3.0

# Via CLI
gh release view v2.3.0
```

### 2. Check Docker Hub
```bash
# Verify images exist
docker pull mitre/vulcan:v2.3.0
docker pull mitre/vulcan:latest

# Check platforms
docker manifest inspect mitre/vulcan:v2.3.0 | jq '.manifests[].platform'
# Should show: linux/amd64 and linux/arm64
```

### 3. Test Docker Image
```bash
# Run locally
docker run --rm -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host/db \
  -e SECRET_KEY_BASE=test \
  mitre/vulcan:v2.3.0

# Check version endpoint
curl http://localhost:3000/status | jq '.application.version'
# Should return: "2.3.0"
```

## Troubleshooting

### "Version mismatch" error in workflow
- Ensure VERSION file is committed
- Check VERSION contains only the number (e.g., `2.3.0`, not `v2.3.0`)
- Verify package.json is synced

### Tests fail in CI
- Run tests locally first
- Check database migrations
- Review Actions logs for details

### Docker build fails
- Verify Dockerfile is valid (uses `--target production`)
- Check Docker Hub secrets are configured
- Review build logs in Actions

### Release doesn't trigger
- Verify tag format: `v*.*.*` (e.g., `v2.3.0`)
- Check tag was pushed: `git push origin v2.3.0`
- Verify GitHub Actions are enabled

## CI/CD Configuration

### Required GitHub Secrets

Set in repository Settings → Secrets:
- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub access token

### Workflows

- `.github/workflows/release.yml` - **New automated release** (tag-based)
- `.github/workflows/run-tests.yml` - PR and push testing
- `.github/workflows/push-to-docker.yml` - Legacy (can be deprecated)
- `.github/workflows/create-draft-release.yml` - Legacy (can be deprecated)

## Monitoring

### GitHub
- **Releases**: https://github.com/mitre/vulcan/releases
- **Actions**: https://github.com/mitre/vulcan/actions
- **Tags**: https://github.com/mitre/vulcan/tags

### Docker Hub
- **Tags**: https://hub.docker.com/r/mitre/vulcan/tags
- **Insights**: https://hub.docker.com/r/mitre/vulcan

### Production
```bash
# Check deployed version
curl https://your-instance.com/status | jq '.application'
```

## Best Practices

1. ✅ **Test before tagging** - No exceptions
2. ✅ **Update CHANGELOG** - Keep users informed
3. ✅ **Use semantic versioning** - Major.Minor.Patch
4. ✅ **Tag from master** - Except hotfixes
5. ✅ **One tag, one version** - Never reuse
6. ✅ **Monitor automation** - Watch Actions complete
7. ✅ **Verify images** - Test published Docker images
8. ✅ **Communication** - Notify users of breaking changes

## Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [rails_app_version gem](https://rubygems.org/gems/rails_app_version)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Docker Multi-Platform Builds](https://docs.docker.com/build/building/multi-platform/)
