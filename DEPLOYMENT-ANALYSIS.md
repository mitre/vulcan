# Vulcan Deployment Configuration Analysis

## Current State Audit

### Configuration Files (18 files)

**Docker:**
- `Dockerfile` (dev/test builds)
- `Dockerfile.production` (optimized production)
- `docker-compose.yml` (production stack)
- `docker-compose.dev.yml` (dev database only)

**Process Management:**
- `Procfile` (production: puma + release)
- `Procfile.dev` (dev: rails s + yarn watch)

**Secrets:**
- `setup-docker-secrets.sh` (generates .env for Docker)
- `.env.production.example` (template)

**Settings:**
- `config/settings.rb` (Settings gem loader)
- `config/vulcan.default.yml` (defaults with ERB for ENV vars)
- `config/database.yml` (DB config)

**Deployment Docs:**
- `docs/deployment/docker.md`
- `docs/deployment/kubernetes.md`
- `docs/deployment/bare-metal.md`
- `docs/deployment/heroku.md`
- `docs/deployment/monitoring.md`

### Deployment Targets Supported

1. **Local Development** - Foreman + Postgres
2. **Docker Compose** - Full stack containers
3. **Kubernetes** - Helm chart (separate repo)
4. **Heroku** - PaaS deployment
5. **Bare Metal** - systemd + nginx

---

## Current Inconsistencies

### Problem 1: Database Names
- Dev: `vulcan_vue_development`
- Prod Docker: `vulcan_vue_production` (docker-compose.yml)
- K8s: `vulcan_psql_production` (Helm chart)

### Problem 2: Two Procfiles
- `Procfile.dev` - dev: rails + yarn
- `Procfile` - prod: puma + release (no yarn!)

### Problem 3: Two docker-compose Files
- `docker-compose.dev.yml` - DB only
- `docker-compose.yml` - Full stack

### Problem 4: Secrets Generation
- Local: Manual or defaults
- Docker: `setup-docker-secrets.sh` → `.env`
- Helm: Different script in helm repo → `vulcan-secrets.yaml`

### Problem 5: Settings Source
- YAML has defaults
- ENV vars override (via ERB)
- Some hardcoded in database.yml (dev password)

---

## What Works Well ✅

### 1. Settings Gem Architecture
- ✅ ENV-first via ERB
- ✅ YAML defaults fallback
- ✅ Structured access
- ✅ Works across all deployments

**Decision: KEEP Settings gem**

### 2. Separate Dockerfiles
- ✅ `Dockerfile` - dev/test (includes dev tools)
- ✅ `Dockerfile.production` - optimized (jemalloc, multi-stage)

**Decision: KEEP both Dockerfiles**

### 3. Health Check Endpoints
- ✅ `/up`, `/health_check`, `/status`
- ✅ Consistent across all deployments

**Decision: Already good**

---

## Research: Community Standards

### Rails 8 (2025) Standard Stack

**Local Dev:**
```bash
bin/setup          # Rails 8 default setup script
bin/dev            # Rails 8 default (runs Procfile.dev)
```

**Docker:**
```yaml
# docker-compose.yml - ONE file with profiles
services:
  db:
    # ...

  web:
    profiles: [dev, prod]
    # Different config via profiles
```

**Secrets:**
```
.env               # Local (gitignored)
.env.example       # Template (committed)
# NO generation scripts
```

### 12-Factor App Principles

1. **Config in environment** ✅ (Vulcan does this via Settings+ENV)
2. **Dev/prod parity** ⚠️ (Different Procfiles, docker-compose)
3. **One codebase** ✅
4. **Explicit dependencies** ✅ (Gemfile)

---

## Proposed Unified Design

### Goal: **Minimal Files, Maximum Flexibility**

### Files to KEEP
```
Dockerfile                    # Dev/test builds
Dockerfile.production         # Optimized production
Procfile                      # Unified (works for all)
docker-compose.yml            # Unified (with profiles or smart defaults)
config/vulcan.default.yml     # Settings with ENV ERB
config/database.yml           # Simplified to use DATABASE_URL
.env.example                  # Template
bin/setup                     # Rails 8 standard
```

### Files to REMOVE
```
❌ Procfile.dev              # Merge into Procfile
❌ docker-compose.dev.yml    # Merge into docker-compose.yml
❌ setup-docker-secrets.sh   # Replace with bin/setup
```

---

## Option A: Minimal Change (Conservative)

**Keep separate files, just standardize:**
1. Rename databases to `vulcan_development`, `vulcan_production`
2. Make `Procfile.dev` work for production too
3. Simplify secret generation (just cp .env.example .env)
4. Document clearly

**Time:** 1 hour
**Risk:** Low
**Benefit:** Consistency without breaking existing workflows

---

## Option B: Full Rails 8 Modernization (Aggressive)

**Unify everything:**
1. ONE Procfile (with conditional logic for prod vs dev)
2. ONE docker-compose.yml (with profiles or env-based)
3. DATABASE_URL everywhere (simplify database.yml)
4. bin/setup does secret generation
5. Remove all custom scripts

**Time:** 3-4 hours
**Risk:** Medium (might break existing setups)
**Benefit:** Rails 8 standard, easier onboarding

---

## Option C: Hybrid (Pragmatic)

**Fix pain points, keep what works:**
1. ✅ Keep Settings gem (works well)
2. ✅ Keep two Dockerfiles (different purposes)
3. ✅ Unify Procfile (remove .dev variant)
4. ✅ Unify docker-compose (use env vars for differences)
5. ✅ Simplify secrets (.env.example → .env, no script)
6. ✅ Standardize database names

**Time:** 2 hours
**Risk:** Low-Medium
**Benefit:** Consistency + standards without disruption

---

## My Recommendation

**Option C - Pragmatic Hybrid**

**Why:**
- Don't fix what works (Settings gem, Dockerfiles)
- Fix what's inconsistent (Procfiles, docker-compose, DB names)
- Remove unnecessary complexity (secret scripts)
- Align with Rails 8 where it makes sense

**Next step: Should I create a detailed refactoring plan for Option C?**