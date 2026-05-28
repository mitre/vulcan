# Vulcan v2.3.0 - Complete Standardization Plan

**Date:** 2025-11-16
**Goal:** Adopt industry standards, remove duplication, create stable foundation
**Approach:** Step-by-step, test everything, commit when working

---

## Standards We're Adopting

1. **dockerfile-rails** - Rails community standard for Docker (Fly.io/Rails core)
2. **Rails config_for + Settings** - Centralized configuration (already using mitre-settingslogic)
3. **Twelve-Factor App** - Environment-based config
4. **Rails 8 patterns** - bin/setup, bin/dev, Procfile

---

## Implementation Steps

### Step 1: Commit Current Prometheus Work ✅
**What:** Save existing uncommitted Prometheus work before making changes

**Tasks:**
- [ ] Stage: Gemfile, Gemfile.lock
- [ ] Stage: config/initializers/prometheus.rb
- [ ] Stage: spec/requests/metrics_spec.rb
- [ ] Stage: config/routes.rb (prometheus comments)
- [ ] Commit: "feat: Add Prometheus metrics integration"
- [ ] Verify commit looks correct

**Test:** git log shows the commit, git status shows only Dockerfile files remaining

---

### Step 2: Commit Dockerfile Work (Current Version) ✅
**What:** Save current Dockerfile improvements before replacing them

**Tasks:**
- [ ] Stage: Dockerfile
- [ ] Stage: Dockerfile.production
- [ ] Stage: docs/deployment/monitoring.md
- [ ] Commit: "feat: Improve Dockerfiles with Node.js fix and cert support"
- [ ] Verify commit

**Test:** git status shows clean (only internal docs untracked)

---

### Step 3: Add dockerfile-rails Gem ✅
**What:** Install the tool for generating standard Dockerfiles

**Tasks:**
- [ ] Add to Gemfile: `gem 'dockerfile-rails', group: :development`
- [ ] Run: `bundle install`
- [ ] Verify: `bundle exec rails generate dockerfile --help` works
- [ ] Commit: "chore: Add dockerfile-rails for Docker standardization"

**Test:** Gem installs, generator available

---

### Step 4: Backup Current Dockerfiles ✅
**What:** Preserve current Dockerfiles before regenerating

**Tasks:**
- [ ] Copy: `cp Dockerfile Dockerfile.custom.backup`
- [ ] Copy: `cp Dockerfile.production Dockerfile.production.custom.backup`
- [ ] Don't commit backups (just for safety)

**Test:** Backup files exist

---

### Step 5: Generate New Dockerfile ✅
**What:** Use dockerfile-rails to create standard Dockerfile

**ACTUAL TASKS REQUIRED:**
- [x] Run: `rails generate dockerfile --postgresql --jemalloc --compose --force`
- [x] **CRITICAL:** Add nkf gem to Gemfile first (Ruby 3.4 compatibility warning)
- [x] Review generated files - all created successfully
- [x] **DISCOVERED:** Need to add custom build packages for fast_excel gem
- [x] **DISCOVERED:** Need CA certificate handling for corporate environment
- [x] **DISCOVERED:** Need custom port 9394 for Prometheus
- [x] **DISCOVERED:** Need db:migrate instead of db:prepare for production

**What we learned:**
- Generated Dockerfile needs customization via config files
- Corporate environments need CA cert instructions
- App-specific gems may need build dependencies

**Test:** Files generated, but needed iteration to work

---

### Step 6: Customize Generated Dockerfile for Prometheus ✅ (via deploy instructions)
**What:** Add port 9394 for Prometheus metrics

**ACTUAL TASKS REQUIRED:**
- [x] **CORRECT APPROACH:** Create config/dockerfile-instructions-deploy.dockerfile
- [x] Add `EXPOSE 9394` in instruction file (not directly in Dockerfile)
- [x] Reference in config/dockerfile.yml: `instructions: deploy: config/dockerfile-instructions-deploy.dockerfile`
- [x] Regenerate to apply

**What we learned:**
- Don't edit generated Dockerfile directly - it gets overwritten
- Use instruction files for customizations
- Instruction files become part of single source of truth

**Files created:**
- config/dockerfile-instructions-deploy.dockerfile

**Test:** Port 9394 persists across regenerations

---

### Step 7: Test Docker Build ✅ (required: git, gnupg, zlib1g-dev packages)
**What:** Verify new Dockerfile actually builds

**ACTUAL TASKS REQUIRED:**
- [x] **FAILED FIRST:** Build failed on fast_excel gem compilation
- [x] **ROOT CAUSE:** Missing zlib1g-dev package (fast_excel needs compression library)
- [x] **ALSO NEEDED:** git and gnupg packages (not auto-detected)
- [x] **SOLUTION:** Create config/dockerfile-instructions-base.dockerfile for CA certs
- [x] **SOLUTION:** Add packages to config/dockerfile.yml
- [x] **FINAL CONFIG:**
  ```yaml
  packages:
    build:
      - git         # Gems from git repos
      - gnupg       # Apt operations
      - zlib1g-dev  # fast_excel compression
  instructions:
    base: config/dockerfile-instructions-base.dockerfile
  ```
- [x] Build: `docker buildx build --platform linux/arm64 -t vulcan:standardization-test --load .`
- [x] **SUCCESS:** Build completed

**What we learned:**
- Generated Dockerfile doesn't detect all native gem requirements
- fast_excel gem bundles libxlsxwriter C library, needs zlib
- Corporate CA certs must be installed in base stage
- Need to test actual build to discover missing dependencies

**Files created:**
- config/dockerfile-instructions-base.dockerfile (CA cert handling)

**Test:** Build succeeds after adding correct dependencies

---

### Step 8: Test Docker Run ✅ (working - /up, /status, /metrics all functional)
**What:** Verify built image actually works

**ACTUAL TASKS REQUIRED:**
- [x] **FAILED FIRST:** Container crashed during db:prepare (tried to seed in production)
- [x] **ROOT CAUSE:** bin/docker-entrypoint uses db:prepare which calls db:seed
- [x] **OUR seeds.rb:** Correctly rejects production environment
- [x] **SOLUTION:** Add `migrate: "./bin/rails db:migrate"` to config/dockerfile.yml
- [x] Regenerate to update entrypoint
- [x] Rebuild image
- [x] Run container:
  ```bash
  docker run -d --name vulcan-test \
    -p 3000:3000 -p 9394:9394 \
    -e SECRET_KEY_BASE=dummy \
    -e DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/vulcan_vue_production \
    vulcan:standardization-test
  ```
- [x] Test /up: ✅ Green HTML
- [x] Test /status: ✅ version 2.3.0
- [x] Test /metrics: ✅ Prometheus working
- [x] Stop container

**What we learned:**
- Default db:prepare isn't appropriate for production (tries to seed)
- Use migrate option to customize database preparation
- seeds.rb should reject non-development environments (already correct)

**Final config addition:**
```yaml
migrate: "./bin/rails db:migrate"
```

**Test:** All endpoints functional, version correct

---

### Step 9: Review Generated docker-compose.yml ⏳
**What:** See if generated compose file meets our needs

**Tasks:**
- [ ] Read generated docker-compose.yml
- [ ] Check it has:
  - [ ] PostgreSQL service
  - [ ] Ports 3000, 9394
  - [ ] Volume for database
  - [ ] Proper depends_on
- [ ] Compare with our docker-compose.dev.yml
- [ ] Decide if we keep generated or customize

**Test:** Understand what we got

---

### Step 10: Test docker-compose ⏳
**What:** Verify compose file works

**Tasks:**
- [ ] Stop all running Docker
- [ ] Run: `docker-compose up`
- [ ] Test endpoints
- [ ] Check logs for errors
- [ ] Stop: `docker-compose down`

**Test:** Compose works, app accessible

---

### Step 11: Commit Dockerfile Standardization ⏳
**What:** Save the new standard Dockerfile

**Tasks:**
- [ ] Delete backup files if tests passed
- [ ] Stage: Dockerfile, .dockerignore, bin/docker-entrypoint, config/dockerfile.yml
- [ ] Stage: docker-compose.yml (if keeping generated)
- [ ] Commit: "feat: Consolidate to single Dockerfile using dockerfile-rails"
- [ ] Note: Replaces custom Dockerfiles with Rails community standard

**Test:** Commit looks good, nothing broken

---

### Step 12: Extend Settings for Ports/Endpoints ⏳
**What:** Use existing Settings gem to centralize configuration

**Tasks:**
- [ ] Edit config/vulcan.yml - add ports and endpoints section
- [ ] Test locally: `rails console` → `Settings.ports.web`
- [ ] Don't change code yet, just add config

**Test:** Can access Settings.ports.metrics, etc.

---

### Step 13: Update Code to Use Centralized Config ⏳
**What:** Replace hardcoded values with Settings

**Tasks:**
- [ ] Find all hardcoded 3000, 9394, 5432
- [ ] Replace with Settings.ports references
- [ ] Update prometheus initializer
- [ ] Update Procfile.dev if needed
- [ ] Commit: "refactor: Use centralized Settings for ports and endpoints"

**Test:** App still works, no hardcoded ports

---

### Step 14: Run Full Test Suite ⏳
**What:** Ensure nothing broken

**Tasks:**
- [ ] bundle exec rspec
- [ ] bundle exec rubocop --autocorrect-all
- [ ] Fix any issues
- [ ] yarn lint
- [ ] Fix any issues
- [ ] bundle exec brakeman
- [ ] Review warnings
- [ ] Commit any fixes

**Test:** All tests pass, linting clean

---

### Step 15: Test Local Development ⏳
**What:** Verify local dev workflow still works

**Tasks:**
- [ ] Stop all servers
- [ ] Run: `foreman start -f Procfile.dev` (current method)
- [ ] Test app works
- [ ] Test metrics work
- [ ] Stop server

**Test:** Local development functional

---

### Step 16: Test Docker Build Multi-Platform ⏳
**What:** Verify multi-platform builds work

**Tasks:**
- [ ] Build: `docker buildx build --platform linux/amd64,linux/arm64 -t vulcan:v2.3.0-test .`
- [ ] Verify both platforms build
- [ ] Check build time

**Test:** Multi-platform build succeeds

---

### Step 17: Coordinate with Helm Chart ⏳
**What:** Ensure helm chart works with new Docker image

**Tasks:**
- [ ] Build image: `docker build -t vulcan:v2.3.0-test .`
- [ ] Switch to vulcan-helm directory
- [ ] Test helm install with new image
- [ ] Verify health checks work
- [ ] Verify Prometheus scraping works
- [ ] Document any helm chart changes needed

**Test:** Helm chart works with standardized Dockerfile

---

### Step 18: Update Documentation ⏳
**What:** Document the new standards

**Tasks:**
- [ ] Update README.md - Docker section
- [ ] Update docs/deployment/docker.md - New approach
- [ ] Update docs/deployment/kubernetes.md - Reference dockerfile-rails
- [ ] Remove setup-docker-secrets.sh references
- [ ] Explain WHY we use dockerfile-rails
- [ ] Commit: "docs: Update for dockerfile-rails standardization"

**Test:** Documentation clear

---

### Step 19: Add Deprecation to setup-docker-secrets.sh ⏳
**What:** Warn users before removing script

**Tasks:**
- [ ] Add deprecation notice at top of script
- [ ] Redirect to use .env.example + bin/setup
- [ ] Commit: "chore: Deprecate setup-docker-secrets.sh"
- [ ] Plan removal for v2.4.0

**Test:** Script shows warning

---

### Step 20: Final Testing - Everything ⏳
**What:** Test every deployment method

**Tasks:**
- [ ] Local: foreman start -f Procfile.dev
- [ ] Docker: docker build + docker run
- [ ] Compose: docker-compose up
- [ ] Multi-platform build
- [ ] Helm chart integration
- [ ] All tests pass
- [ ] All linting clean

**Test:** Everything works

---

### Step 21: Update db/schema.rb ⏳
**What:** Commit auto-generated schema

**Tasks:**
- [ ] Stage: db/schema.rb
- [ ] Commit: "chore: Update database schema"

**Test:** Schema committed

---

### Step 22: Final Review and Push ⏳
**What:** Push to origin for review

**Tasks:**
- [ ] Review all commits on v2.3.0
- [ ] Update PR #699 description with full changelist
- [ ] git push origin v2.3.0 -f (if rebased) or git push origin v2.3.0
- [ ] Request review
- [ ] Tag team about helm chart coordination

**Test:** PR ready for review

---

## Success Criteria

- [ ] One Dockerfile (generated by dockerfile-rails)
- [ ] All tests passing (268 examples)
- [ ] All linting clean
- [ ] Docker builds work (amd64 + arm64)
- [ ] docker-compose works
- [ ] Helm chart tested and working
- [ ] Configuration centralized via Settings
- [ ] No hardcoded ports/endpoints
- [ ] Documentation updated
- [ ] setup-docker-secrets.sh deprecated

---

## Current Status

**Step:** Ready to start Step 1
**Branch:** v2.3.0
**Tests:** ✅ 268 passing
**Uncommitted:** Prometheus files, Dockerfiles

---

**This plan will be followed step-by-step. No skipping ahead.**
