# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Mission

Vulcan helps security teams create STIG-ready security guidance documentation. Users author "Components" (STIGs in progress) that implement requirements from SRGs (Security Requirements Guides). Once reviewed by DISA/DoD, Components become published STIGs.

**Key Concept**: Component = "STIG in progress" - same structure, different lifecycle stage.

---

## ⚠️ ABSOLUTE PRIORITIES - NON-NEGOTIABLE ⚠️

**These rules override EVERYTHING else. No exceptions. No excuses.**

0. **WHEN THE USER IS FRUSTRATED, SLOW DOWN** - Do NOT try to move faster. Do NOT bulk-operate without verifying each item. Do NOT fabricate explanations. VERIFY EVERYTHING. Say "I don't know" when you don't know. Moving fast when trust is broken destroys the relationship. The user WILL call you out. You WILL redo fucked up work. Get it right the first time by slowing down.

1. **CORRECT CODE OVER SPEED** - Never rush. Never cut corners. Take the time to do it right.

2. **FIX ALL BUGS WHEN FOUND** - Period. No "pre-existing" excuses. No "out of scope" dismissals. We own ALL the code in this repository. If you find a bug, you fix it. NOW.

3. **BEST PRACTICES AND STANDARDS — ALWAYS, NO EXCEPTIONS** - Always use DRY, best practice, maintainable, standards-compliant solutions. Research the proper way. Follow established patterns. No shortcuts. No quick fixes. No hacks. No workarounds. No "document what exists and card the real fix for later." If the code is wrong, FIX THE CODE. If the API is inconsistent, MAKE IT CONSISTENT. If there is a proper pattern, USE IT. Every single time.

4. **NO HACKS, WORKAROUNDS, OR "JUST MAKING IT WORK"** - If the solution feels like a hack, it IS a hack. Stop. Find the proper solution.

5. **DO NOT GUESS - RESEARCH FIRST** - Before trying solutions, RESEARCH the problem. Search GitHub issues, documentation, Stack Overflow. Find how others solved it. Guessing wastes time and creates technical debt.

6. **RECOVERY CARDS ARE MANDATORY** - Before compact: ALWAYS update the recovery card with CURRENT, ACCURATE information. After compact: EXECUTE the recovery commands IMMEDIATELY. Do not read random files. Do not ask questions. Run the commands provided.

7. **DRY - DON'T REPEAT YOURSELF** - ALWAYS design reusable components FIRST. Before touching ANY existing code, ask: "Will I need to make this same change in multiple places?" If YES, create a reusable component/function/mixin FIRST, then use it everywhere. NEVER scatter the same logic across multiple files. ONE source of truth. ONE place to change.

8. **STOP. UNDERSTAND. SPEC. THEN CODE.** - Before making ANY changes to UI components:
   - STOP: Do not touch code yet
   - UNDERSTAND: Map out the existing architecture. What components exist? How are they shared? What props do they use?
   - SPEC: Document what the expected behavior should be in EACH state/mode BEFORE coding
   - THEN CODE: Only after you have a clear spec, make changes
   - If you find yourself adding props to HIDE functionality, you're doing it wrong. Ask first.
   - If two pages should behave the same, they should use the SAME component with the SAME props.
   - NEVER assume differences between pages are intentional. ASK.

**What this means in practice:**
- Found a test warning? FIX IT. Don't say "it still passes."
- Found bad code? FIX IT. Don't say "it was already there."
- Unsure of the right approach? RESEARCH IT. Don't guess.
- Taking longer than expected? THAT'S FINE. Correct code takes time.
- Running prepare-compact? UPDATE THE RECOVERY CARD WITH CURRENT INFO. Not stale info. CURRENT STATE.
- After compact with recovery prompt? EXECUTE THE COMMANDS IMMEDIATELY. Don't read random files. RUN THE COMMANDS.
- Adding a feature to multiple components? CREATE A REUSABLE COMPONENT FIRST. Don't scatter changes across files.
- Changing UI components? STOP. Map the architecture. Write a spec. Get approval. THEN code.
- Adding a prop to hide/disable functionality? STOP. Ask if the functionality should exist on both pages first.
- Two pages look different? Don't assume it's intentional. ASK before "fixing" by adding conditional props.

**COPY THIS SECTION INTO EVERY RECOVERY FILE.**

---

## Tech Stack

- **Backend**: Ruby 3.4.9, Rails 8.0.2.1, PostgreSQL 18
- **Frontend**: Vue 2.7.16 (14 separate instances), Bootstrap 4.6.2, Bootstrap-Vue 2.13.0
- **Navigation**: Turbolinks 5.2.0 with vue-turbolinks adapter
- **Build**: esbuild via jsbundling-rails, Propshaft asset pipeline
- **Package Manager**: YARN (NOT npm, NOT pnpm)
- **Templates**: HAML (NOT ERB)
- **Settings**: mitre-settingslogic gem with `config/vulcan.default.yml`
- **Documentation**: VitePress 2.x in `docs/` (separate Vue 3 deps, isolated from Rails Vue 2)

---

## Common Commands

```bash
# Development
foreman start -f Procfile.dev    # Start dev server (Rails + esbuild watch)
bin/rails server                 # Rails only (no JS rebuild)
yarn build:watch                 # esbuild watch only

# Testing — ALWAYS use bin/parallel_rspec for full suite (3-4x faster)
bin/parallel_rspec spec/                       # Full suite, capped at 8 cores
# NEVER use bare `bundle exec parallel_rspec` — it auto-detects all CPU cores
# and exceeds the 8 test databases, causing NoDatabaseError on workers 9+.
bundle exec rspec spec/path/to/spec.rb         # Single file
bundle exec rspec spec/path/to/spec.rb:42      # Single test line
yarn test:unit                                 # Vue component tests (Vitest)

# test-prof profiling (zero overhead when ENV vars not set)
TAG_PROF=type bundle exec rspec                # Profile by test type
EVENT_PROF=factory.create bundle exec rspec    # Factory usage profiling
EVENT_PROF=sql.active_record bundle exec rspec # SQL query profiling
FPROF=1 bundle exec rspec                      # Factory cascade detection
FPROF=flamegraph bundle exec rspec             # Factory cascade flamegraph

# IMPORTANT: After running db:migrate, sync all parallel test databases
bundle exec rake parallel:prepare              # Sync schema to all parallel test DBs

# Linting
bundle exec rubocop --autocorrect-all          # Ruby/Rails
yarn lint                                      # JavaScript/Vue (with --fix)
bundle exec brakeman                           # Security scanning
bundle exec bundler-audit                      # Gem vulnerability check

# Database
rails db:migrate
rails db:seed
rails db:reset                                 # Drop, create, migrate, seed
bundle exec rake parallel:prepare              # REQUIRED after any migration — syncs parallel test DBs
bundle exec rails stig_and_srg_puller:pull     # Pull latest STIGs/SRGs

# Docker
./setup-docker-secrets.sh                      # Generate .env with secrets
docker compose build                           # Build image
docker compose up                              # Start full stack
docker compose down -v                         # Stop and remove volumes

# Upgrade toolkit (see docs/deployment/upgrade-guide.md)
bundle exec rake upgrade:preflight             # Read-only report: version, pending actions, warnings
bundle exec rake upgrade:fix                   # Apply safe auto-fixable actions (DB renames, backfills)
bundle exec rake upgrade:verify                # Validate post-upgrade state (migrations, DB names, env)
bundle exec rake upgrade:auto                  # Preflight + fix in one shot (used by entrypoints)

# Documentation (VitePress — runs from project root)
yarn docs:dev                                  # Start VitePress dev server (hot reload)
yarn docs:build                                # Build static site to docs/.vitepress/dist/
yarn docs:preview                              # Preview production build locally
```

---

## Architecture

### Vue.js Structure (14 Separate Instances)

Each page has its own Vue instance mounted via a pack file in `app/javascript/packs/`. They do NOT share a router or global store - each is independent.

Entry points (configured in `esbuild.config.js`):
- `application.js` - Base with Turbolinks/Rails UJS setup
- `navbar.js`, `toaster.js` - Global UI (present on every page)
- `login.js` - Login page
- `projects.js`, `project.js` - Project management
- `project_components.js`, `project_component.js` - Component editing
- `rules.js` - Rule management
- `security_requirements_guides.js`, `stig.js`, `stigs.js` - SRG/STIG views
- `users.js` - User management

All packs use `vue-turbolinks` mixin for Turbolinks compatibility. Components are in `app/javascript/components/`, shared utilities in `app/javascript/store/` and `app/javascript/mixins/`.

### Key Models

- `Project` - Container for components, has many `Membership` records
- `Component` - STIG-ready content with rules (belongs to Project + SRG)
- `Rule` - Individual security control (mapped to SRG requirement via `rule_id`)
- `SecurityRequirementsGuide` (SRG) - DISA baseline requirements
- `Stig` - Published STIGs for reference
- `User` - Authentication via Devise (local, GitHub, LDAP, OIDC)
- `Membership` - User-to-Project access (role-based)
- `ProjectAccessRequest` - Request to join a project
- `Review` - Workflow review on a rule

### Authentication

Devise with four providers configured in `config/initializers/devise.rb`:
- Local (email/password)
- GitHub (omniauth-github)
- LDAP (gitlab_omniauth-ldap)
- OIDC (omniauth_openid_connect with auto-discovery)

Provider enable/disable controlled by environment variables via `config/vulcan.default.yml`.

### Admin Bootstrap (v2.2.2+)

Three methods, in priority order:
1. **Env vars**: `VULCAN_ADMIN_EMAIL` + `VULCAN_ADMIN_PASSWORD` - runs on `db:prepare` via `lib/tasks/admin_bootstrap.rake`
2. **First-user-admin**: `VULCAN_FIRST_USER_ADMIN=true` - `after_create` callback in User model with PostgreSQL advisory lock
3. **Manual**: `rails db:create_admin`

### STIG/SRG XML Parsing

`app/lib/xccdf/` contains parsers for DISA XCCDF XML format. SRGs and STIGs are imported from XML files via upload or `stig_and_srg_puller:pull` rake task.

---

## Testing Patterns

### Request Specs (Rails 8)
```ruby
RSpec.describe 'Resource', type: :request do
  before do
    Rails.application.reload_routes!  # Required for Rails 8 lazy loading
  end

  it 'requires authentication' do
    post '/stigs', params: { file: file }
    expect(response).to redirect_to(new_user_session_path)
  end

  context 'when authenticated' do
    before { sign_in user }  # Devise::Test::IntegrationHelpers
    # ...
  end
end
```

### RSpec let! Ordering (Critical)

`let!` creates an implicit `before` hook that runs in **definition order** relative to explicit `before` blocks. Always define `let!` declarations BEFORE `before` blocks:

```ruby
# CORRECT - admin created before sign_in triggers user creation
let!(:existing_admin) { create(:user, admin: true) }
before { sign_in user }

# WRONG - sign_in runs first, user becomes first-user-admin
before { sign_in user }
let!(:existing_admin) { create(:user, admin: true) }
```

### test-prof Best Practices

- **`let_it_be`** for expensive setup (SRG parsing, component creation). Creates once per group, reuses across examples.
- **Global `refind: true`** configured in `rails_helper.rb` — every `let_it_be` record gets a fresh AR instance per example. Never override with `refind: false`.
- **`before_all`** for setup that must run once per group (memberships, associations). Wrapped in a transaction that rolls back after the group.
- **No `@ivar` aliases** — use `let_it_be` names directly in shared contexts. The dual-naming pattern (`@p_admin = shared_p_admin`) is deprecated.
- **Custom RuboCop cop** `Vulcan/LetItBeRefind` enforces `refind: false` is never used.

### Parallel Test Safety

- **ENV mutation**: Use `climate_control` gem, never bare `ENV['X'] = value`
- **Record identity**: Never use `Record.last` — use scoped queries or response body IDs
- **Global state**: Never `Audited.auditing_enabled = false` — use `Model.without_auditing { }`
- **Shared fixtures**: Never `ensure { record.update_columns }` on `let_it_be` — use local records
- **Spec file size**: Target ~300 lines, hard cap 500. Use `/spec-split-review` skill to split.

### Spec File Organization

- Flat naming: `reviews_triage_spec.rb`, not `reviews/triage_spec.rb`
- Shared contexts in `spec/support/shared_contexts/`
- Shared examples in `spec/support/shared_examples/`
- Full testing guide: `docs/development/testing.md`

---

## Docker Deployment

### Architecture
- **Dockerfile**: Multi-stage on UBI 9 Minimal (base, build-base, build, development, production) with jemalloc + YJIT compiled from source
- **docker-compose.yml**: PostgreSQL + Vulcan web, `env_file: required: false`
- **bin/docker-entrypoint**: Rails standard pattern - runs `db:prepare` on server start
- **setup-docker-secrets.sh**: Generates `.env` with secure random secrets

### Flow
```
setup-docker-secrets.sh -> .env (secrets)
docker compose up -> PostgreSQL starts -> health check passes
                  -> web starts -> docker-entrypoint runs db:prepare
                  -> admin:bootstrap hooks into db:prepare
                  -> Rails server starts on :3000
```

### Defaults
- Non-secret ENV defaults set in Dockerfile (auth, SSL, first-user-admin)
- Database credentials use variable substitution in docker-compose.yml: `${POSTGRES_PASSWORD:-postgres}`
- Secrets (SECRET_KEY_BASE, CIPHER_PASSWORD, CIPHER_SALT) must be provided externally
- No static secrets in config files

---

## Configuration

### Environment Variables

See `ENVIRONMENT_VARIABLES.md` for complete list. Key ones:
- `SECRET_KEY_BASE`, `CIPHER_PASSWORD`, `CIPHER_SALT` - Required secrets
- `DATABASE_URL` - PostgreSQL connection (or individual POSTGRES_* vars)
- `VULCAN_ENABLE_OIDC`, `VULCAN_OIDC_ISSUER_URL`, `VULCAN_OIDC_CLIENT_ID/SECRET`
- `VULCAN_ENABLE_LDAP`, `VULCAN_LDAP_*`
- `VULCAN_ENABLE_LOCAL_LOGIN`, `VULCAN_ENABLE_USER_REGISTRATION`
- `VULCAN_FIRST_USER_ADMIN` - First user becomes admin
- `VULCAN_ADMIN_EMAIL`, `VULCAN_ADMIN_PASSWORD` - Env var admin bootstrap
- `RAILS_FORCE_SSL` - Defaults to false for Docker quickstart
- `RAILS_LOG_TO_STDOUT` - Container logging

### Settings Flow

`config/vulcan.default.yml` is an ERB template that reads environment variables with fallback defaults. Accessed in code via `Settings.section.key`.

### Pre-commit Hooks (.overcommit.yml)

- RuboCop with autocorrect
- ESLint for JavaScript/Vue
- BundleCheck, RailsSchemaUpToDate
- YamlSyntax, JsonSyntax validation

---

## Recovery & Context Management

### Recovery File Convention
- Format: `RECOVERY-v2.2.2-SESSION##.md`
- Location: Project root (NOT committed to git)
- Create before context drops below 15%
- Always create a NEW file - never overwrite existing ones
- Session numbers increment: SESSION136, SESSION137, etc.

---

## Git Workflow

### Commit Rules
- **NEVER** use `git add -A` or `git add .` - add files individually
- Run `git status` first to review changes
- All tests and linting must pass before committing
- **ALWAYS** backup before destructive git operations

### Best-of-Breed Merge
When rebasing or merging concurrent work from collaborators (Aaron + Will work the same branch), **NEVER blindly take one side.** Review BOTH implementations and cherry-pick the best code, tests, and patterns from each side. Compare both versions, keep the better tests regardless of author, use the better pattern regardless of who wrote it. If both sides can be improved during the merge, do that too. "Ours" or "theirs" as a default is lazy and loses good work.

### When to Commit (Workflow Preference)
**DO NOT constantly suggest commits during feature development.**

Commits should be complete, tested, documented, logical units of work.

**Uncommitted changes mid-feature are NORMAL** - recovery cards handle context preservation.

**Only commit when:**
- User explicitly requests it
- A complete feature set is finished and tested
- Before switching to unrelated work (if user agrees)

**Do NOT suggest commits:**
- Mid-feature development
- Before /compact
- After every small change

### Commit Message Format
```
feat: Add admin bootstrap with advisory lock

- Added rake task for env var admin creation
- Protected first-user-admin with advisory lock
- Added 9 tests for bootstrap scenarios

Authored by: Aaron Lippold<lippold@gmail.com>
```

Prefixes: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`

No Claude signatures in commits.

---

## Code Quality Standards

- **No quick hacks** - Every solution must be properly designed
- **Research before implementing** - Check how Discourse, GitLab, Mastodon handle the same problem
- **No static secrets in config files** - Use setup scripts or env vars
- **Design top-to-bottom before coding** - Don't bolt new features onto old architecture
- **Fix root causes** - Never test around bugs or modify tests just to pass
- **Own all code** - If tests fail, find and fix the actual problem
- **When a component has a bad API, FIX THE API. Don't work around it.** - If you find yourself fighting with a component's design (hiding default behavior, complex workarounds, passing props to disable features), stop and fix the component's API instead. Example: NewComponentModal rendering buttons by default was backwards - fixed by adding `showOpener` prop (default: false). Working around bad design wastes time and creates technical debt.

### OpenAPI Spec as API Contract

The OpenAPI spec at `doc/openapi/` is the **design document** for Vulcan's complete REST API. It is multi-file (managed via Redocly CLI) with the bundled output at `doc/openapi.yaml`.

**Rules:**
- **Every JSON-returning endpoint MUST have an OpenAPI path file** — if a route returns JSON but has no spec, that's an API gap to fix
- **Every OpenAPI path MUST have a contract test** in `spec/contracts/` — validates real responses against the schema
- **API response changes and schema updates are ONE task** — never change a controller render without updating the spec
- **Use `yarn openapi:bundle && yarn openapi:lint`** after any spec changes
- **Use `yarn openapi:docs`** to regenerate the VitePress API reference JSON
- See `doc/openapi/CLAUDE.md` for full documentation standards

---

## Beads Command Safety

Never use heredocs directly in `bd` commands - they corrupt `.claude/settings.local.json`.

```bash
# CORRECT - write to temp file first
cat > /tmp/desc.md <<'EOF'
... long content ...
EOF
bd update <id> --description "$(cat /tmp/desc.md)"
rm /tmp/desc.md
```

---

## Rails 8 Notes

- Lazy route loading requires `Rails.application.reload_routes!` in test setup
- Controller specs no longer work - use request specs
- Built-in reloader replaces Spring gem
- Turbolinks still works but is deprecated

## Do Not Do

1. Don't use `git add -A` or `git add .`
2. Don't rewrite working code without reason
3. Don't add code without tests
4. Don't use npm or pnpm - this project uses YARN
5. Don't prioritize "fast" over "correct"
6. Don't create placeholder/skeleton code and call it "complete"
7. Don't ignore existing codebase patterns - find similar code and match it
8. **NEVER delete ANY files without explicit user permission** - ask first, always

## Tests Verify REQUIREMENTS, Not Implementations

**CRITICAL: Tests that verify what code DOES (instead of what it SHOULD DO) are worthless.**

**The Microsoft Outlook Disaster Pattern:**
- Look at code: "right-panels is inside v-if"
- Write test: "expect right-panels NOT to render when no rule selected"
- Test passes ✓
- Code is BROKEN - panels should ALWAYS render
- Test encoded the BUG as expected behavior

**Before writing ANY test, ask:**
1. What is the REQUIREMENT? (Not "what does the code do?")
2. What SHOULD happen from the user's perspective?
3. Would this test FAIL if the code had a bug?

**Test Writing Rules:**
- Document requirements in test file comments FIRST
- Write test for the requirement
- If test passes immediately, BE SUSPICIOUS - did you just test the implementation?
- MANUALLY VERIFY behavior in browser/UI - don't trust green checkmarks
- Use `mount` not `shallowMount` for integration tests - test real component interaction

**Signs your tests are worthless:**
- You wrote tests AFTER the code and they all passed first try
- Tests use the same logic as the implementation
- You never manually verified the feature works
- Tests break when you refactor but bugs slip through

**The rule:** If your test would pass with buggy code, it's not testing anything.
