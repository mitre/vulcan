# Vulcan v2.3.0 - Rails 8 Modernization Plan

## Goal: Full Rails 8 + Docker + K8s Best Practices

Aggressive modernization to align with 2025 community standards while maintaining government/DoD deployment flexibility.

**IMPORTANT:** One thing at a time. Get this stable in v2.3.0, THEN consider pnpm migration in future release.

---

## Principles

1. **ENV vars are the source of truth** (already true via Settings gem)
2. **One way to do each thing** (remove duplication)
3. **Rails 8 conventions** (bin/setup, bin/dev, DATABASE_URL)
4. **12-factor app compliance** (config in environment)
5. **Developer experience** (simple setup, fast iteration)

---

## Implementation Phases

### Phase 1: Core Refactoring (1 hour)

#### 1.1 Unify Procfile
**Current:**
- `Procfile.dev` - rails s + yarn watch
- `Procfile` - puma + release

**New: ONE Procfile**
```ruby
# Works for dev AND production
web: bundle exec puma -C config/puma.rb
js: yarn build:watch
release: bundle exec rails db:migrate
```

**Changes:**
- Merge Procfile.dev into Procfile
- Delete Procfile.dev

#### 1.2 Simplify database.yml
**Current:**
- Hardcoded dev password
- Different DB names per environment
- Complex configuration

**New: DATABASE_URL-based**
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV.fetch("DATABASE_URL") { "postgres://postgres:postgres@localhost:5432/vulcan_#{Rails.env}" } %>

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
```

**Changes:**
- Rewrite database.yml
- Standardize DB names: `vulcan_development`, `vulcan_test`, `vulcan_production`

#### 1.3 Update .env.example
**Add DATABASE_URL:**
```bash
# Database
DATABASE_URL=postgres://postgres:postgres@localhost:5432/vulcan_development

# Application
SECRET_KEY_BASE=generate_with_bin_setup
POSTGRES_PASSWORD=generate_with_bin_setup
CIPHER_PASSWORD=generate_with_bin_setup
CIPHER_SALT=generate_with_bin_setup

# All VULCAN_* settings...
```

---

### Phase 2: Modern Tooling (1 hour)

#### 2.1 Create bin/setup
**Full Rails 8 setup script:**
```ruby
#!/usr/bin/env ruby
require "fileutils"

def main
  chdir!

  log "== Installing dependencies =="
  system! "gem install bundler --conservative"
  system! "bundle check || bundle install"
  system! "yarn install"

  log "\n== Preparing .env file =="
  setup_env_file

  log "\n== Preparing database =="
  system! "bin/rails db:prepare"  # Creates, migrates, seeds

  log "\n== Compiling assets =="
  system! "bin/rails assets:precompile" if production?

  log "\n== Setup complete! =="
  log "Run 'bin/dev' to start the application"
end

def setup_env_file
  if File.exist?(".env")
    log "✓ .env already exists"
    return
  end

  FileUtils.cp(".env.example", ".env")

  require 'securerandom'
  secrets = {
    "SECRET_KEY_BASE" => SecureRandom.hex(64),
    "POSTGRES_PASSWORD" => SecureRandom.hex(33),
    "CIPHER_PASSWORD" => SecureRandom.hex(64),
    "CIPHER_SALT" => SecureRandom.hex(32)
  }

  env_content = File.read(".env")
  secrets.each do |key, value|
    env_content.gsub!(/^#{key}=.*/, "#{key}=#{value}")
  end
  File.write(".env", env_content)

  log "✅ Generated .env with secure secrets"
end

def chdir!
  FileUtils.chdir File.expand_path("..", __dir__)
end

def system!(*args)
  system(*args, exception: true)
end

def production?
  ENV['RAILS_ENV'] == 'production'
end

def log(message)
  puts message
end

main
```

#### 2.2 Create bin/dev
```bash
#!/usr/bin/env sh

if ! command -v foreman &> /dev/null
then
  echo "Installing foreman..."
  gem install foreman
fi

# Start all processes
exec foreman start -f Procfile "$@"
```

#### 2.3 Unify docker-compose.yml
**ONE file with environment-based behavior:**
```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${DATABASE_NAME:-vulcan_development}
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 10s

  web:
    build:
      context: .
      dockerfile: ${DOCKERFILE:-Dockerfile}
    environment:
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD:-postgres}@db/${DATABASE_NAME:-vulcan_development}
      RAILS_ENV: ${RAILS_ENV:-development}
    env_file: .env
    ports:
      - "3000:3000"
      - "9394:9394"
    depends_on:
      db:
        condition: service_healthy
    command: foreman start
    volumes:
      # Only mount in dev (override with docker-compose.prod.yml if needed)
      - .:/app:cached
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/up"]
      interval: 30s

volumes:
  postgres_data:
```

**Changes:**
- Merge docker-compose.dev.yml into docker-compose.yml
- Delete docker-compose.dev.yml
- Add smart ENV defaults

---

### Phase 3: Cleanup (30 min)

**Files to DELETE:**
- ❌ `Procfile.dev` (merged into Procfile)
- ❌ `docker-compose.dev.yml` (merged into docker-compose.yml)
- ❌ `setup-docker-secrets.sh` (replaced by bin/setup)
- ❌ `fix_java_certs.sh` (temp testing files)
- ❌ `fix_java_certs_complete.sh`
- ❌ `okta.com.pem` (temp testing)
- ❌ `mitre-ba-root.crt` (temp testing)

**Files to UPDATE:**
- ✅ `README.md` - New setup instructions
- ✅ `ENVIRONMENT_VARIABLES.md` - Add DATABASE_URL
- ✅ `.env.production.example` - Update template

---

### Phase 4: Documentation Updates (1 hour)

#### Documentation Matrix

| File | Current State | Changes Needed | Priority |
|------|--------------|----------------|----------|
| **README.md** | Shows foreman + Procfile.dev | Update to bin/setup + bin/dev | HIGH |
| **docs/getting-started/** | | | |
| - installation.md | Multi-step setup | Simplify to bin/setup | HIGH |
| - environment-variables.md | Partial ENV list | Add DATABASE_URL, document all | HIGH |
| **docs/deployment/** | | | |
| - docker.md | Uses setup-docker-secrets.sh | Update to bin/setup | HIGH |
| - kubernetes.md | Points to Helm chart | Note v0.3.0 changes needed | MEDIUM |
| - bare-metal.md | systemd + nginx | Update DB names, ENV vars | MEDIUM |
| - heroku.md | Old Procfile | Update to new Procfile | LOW |
| - monitoring.md | Prometheus setup | Already good ✅ | NONE |
| **ENVIRONMENT_VARIABLES.md** | Partial list | Add DATABASE_URL, standardize | HIGH |
| **.env.production.example** | Old format | Update with all vars, DATABASE_URL | HIGH |

#### Specific Doc Updates

**README.md:**
```markdown
## Quick Start

git clone https://github.com/mitre/vulcan.git
cd vulcan
bin/setup  # Installs deps, creates DB, generates secrets
bin/dev    # Starts application

Visit http://localhost:3000
```

**docs/deployment/docker.md:**
```markdown
## Docker Compose Deployment

# Development
docker-compose up

# Production-like
DOCKERFILE=Dockerfile.production RAILS_ENV=production docker-compose up
```

**docs/deployment/kubernetes.md:**
```markdown
## Database Configuration

Vulcan v2.3.0+ uses standardized database naming:
- Database name: vulcan_production (not vulcan_psql_production)
- Helm chart v0.3.0+ required for compatibility
```

---

### Phase 5: Testing (30 min)

**Test each scenario:**

1. **Local Dev:**
```bash
rm -rf .env
bin/setup
bin/dev
# Visit http://localhost:3000
```

2. **Docker Compose:**
```bash
docker-compose down -v
docker-compose up
# Visit http://localhost:3000
```

3. **Production Mode:**
```bash
RAILS_ENV=production DOCKERFILE=Dockerfile.production docker-compose up
```

4. **Helm Compatibility:**
```bash
# Verify Helm chart env vars still match
grep DATABASE_URL ../vulcan-helm/vulcan/templates/configmap.yaml
```

---

## Helm Chart Impact Assessment

### Changes Needed in vulcan-helm v0.3.0

**ConfigMap (`templates/configmap.yaml`):**
```yaml
data:
  # OLD (if using individual vars)
  POSTGRES_DB: vulcan_psql_production
  POSTGRES_USER: vulcanpostgres

  # NEW (standardized)
  DATABASE_URL: postgres://postgres:{{ .Values.postgresql.auth.password }}@{{ include "vulcan.postgresql.fullname" . }}/vulcan_production
```

**Deployment (`templates/vulcan-deployment.yaml`):**
- Already uses ConfigMap for env ✅
- No changes needed if ConfigMap correct

**Documentation:**
- Update Helm README to note v2.3.0 app changes
- Document DATABASE_URL usage
- Note DB name standardization

**Testing:**
```bash
# After Vulcan v2.3.0 release
helm upgrade vulcan ./vulcan --set vulcan.image.tag=v2.3.0
```

---

## Sub-Project Question: Should vulcan-helm be a subdirectory?

### Current: Separate Repo
```
mitre/vulcan          (Rails app)
mitre/vulcan-helm     (Helm chart)
```

**Pros:**
- ✅ Independent versioning
- ✅ Separate release cycles
- ✅ Can use chart without app source

**Cons:**
- ❌ Coordination complexity
- ❌ Documentation split
- ❌ Testing requires both repos

### Option: Monorepo
```
mitre/vulcan/
  app/              (Rails app)
  chart/            (Helm chart)
  docs/             (Unified docs)
```

**Pros:**
- ✅ Single source of truth
- ✅ Coordinated releases
- ✅ Easier testing

**Cons:**
- ❌ Larger repo
- ❌ Helm users must clone full app
- ❌ Migration complexity

### Recommendation: **Keep Separate for Now**

**Why:**
- Helm chart can be used independently
- Different user bases (app devs vs DevOps)
- Rails + Helm monorepo is NOT standard practice

**BUT:** Improve coordination via:
- Shared CHANGELOG
- Version compatibility matrix
- Integration tests

**Agree with "one thing at a time"** - modernize v2.3.0 first, revisit monorepo in future if pain persists.

---

## Implementation Checklist

### Vulcan App (v2.3.0)
- [ ] Phase 1: Core refactoring
- [ ] Phase 2: Tooling (bin/setup, bin/dev)
- [ ] Phase 3: Cleanup old files
- [ ] Phase 4: Update 8 documentation files
- [ ] Phase 5: Test all scenarios
- [ ] Commit and push

### Vulcan Helm (v0.3.0 - AFTER app done)
- [ ] Update ConfigMap with DATABASE_URL
- [ ] Update documentation
- [ ] Test with v2.3.0 app
- [ ] Update version compatibility matrix
- [ ] Commit and release

**Total: 4 hours (Vulcan) + 1 hour (Helm) = 5 hours**

---

**Ready to start Phase 1: Core Refactoring?**
