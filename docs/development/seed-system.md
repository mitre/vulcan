# Seed System

Vulcan's seed system follows the [GitLab/ThoughtBot two-concern pattern](https://thoughtbot.com/blog/priming-the-pump): production-required data (admin bootstrap, SRGs/STIGs) is separate from development demo data (sample users, projects, comments).

## Architecture

```
db/
├── seeds.rb                     # Loader — wraps all files in SeedHelpers.quiet
└── seeds/
    └── data/
        ├── 00_users.rb          # Admin + role-tier + community SME users
        ├── 01_projects.rb       # Demo projects
        ├── 02_srgs.rb           # SRG XCCDF XML imports
        ├── 03_stigs.rb          # STIG XCCDF XML imports
        ├── 04_components.rb     # Named + overlay + dummy components
        ├── 05_memberships.rb    # ALL memberships — demo + community personas
        ├── 06_rule_statuses.rb  # Varied statuses for demo coverage
        ├── 07_additional_questions.rb  # AdditionalQuestion + AdditionalAnswer
        ├── 08_rule_descriptions.rb     # RuleDescription records
        ├── 09_access_requests.rb       # ProjectAccessRequest records
        ├── 10_comments.rb       # YAML-driven comment threads via SeedContext
        ├── 11_cross_project.rb  # Cross-project comments
        ├── 12_personal_access_tokens.rb  # PAT records
        ├── 13_container_srg_test.rb      # Container SRG Test dataset
        └── threads.yml          # Declarative thread definitions (Chatwoot pattern)
    └── srgs/                    # DISA SRG XCCDF XML files
    └── stigs/                   # DISA STIG XCCDF XML files

lib/
├── seed_helpers.rb              # Shared helpers (SeedHelpers module)
├── seed_context.rb              # SeedContext — centralized lookups
└── tasks/
    └── dev.rake                 # User-facing rake tasks
```

### Design Decisions

- **No seed management gem.** We evaluated seed-fu, seedbank, and others. The complexity of XCCDF parsing, polymorphic comments, and triage state machines means 80%+ of seeds need custom Ruby. Modular numbered files give the same benefits with zero dependencies.
- **YAML data + Ruby infrastructure.** Comment thread definitions live in `threads.yml` (Chatwoot pattern) — data as YAML, not inline Ruby constants. The `SeedHelpers.load_threads` method normalizes YAML to the symbol-keyed format `seed_thread` expects.
- **SeedContext for centralized lookups.** `SeedContext` pre-loads all users (indexed by email), projects (by name), and components (by name) in one pass. Seed files receive the context instead of doing scattered `User.find_by` calls.
- **Quiet infrastructure wrapper.** `SeedHelpers.quiet` suppresses Devise mailer deliveries and audit logging during seeding (GitLab pattern). All seed files run inside this wrapper via `seeds.rb`.
- **Every seed file is idempotent.** Uses `find_or_create_by`, `find_or_initialize_by`, or `SeedHelpers.find_or_seed_review`. Running `rails db:seed` twice produces identical data.
- **Membership creation centralized.** ALL membership wiring (demo users + community personas) lives in `05_memberships.rb` only. Comment seeds do NOT create memberships.

## Commands

| Command | Purpose | Safe to repeat? |
|---------|---------|----------------|
| `rails db:seed` | Load all seed data (gated by env in production) | Yes |
| `rails dev:prime` | Alias for `db:seed` — loads demo data | Yes |
| `rails dev:status` | Report record counts per model | Read-only |
| `rails dev:verify` | Check seed data completeness + RBAC coverage | Read-only |
| `rails dev:reset` | Clear demo comments and re-prime | Destructive |

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `VULCAN_SEED_DEMO_DATA` | `false` | Set to `true` to seed demo data in production |
| `VULCAN_SEED_ADMIN_PASSWORD` | `12qwaszx!@QWASZX` | Password for all demo users |

In development/test environments, demo data is always seeded regardless of `VULCAN_SEED_DEMO_DATA`.

## SeedHelpers API

The `SeedHelpers` module (`lib/seed_helpers.rb`) provides shared helpers for all seed files:

### `SeedHelpers.seed_xccdf(filepath)`

Parse a DISA XCCDF XML file and create the corresponding SRG or STIG record. Idempotent — skips if `srg_id` / `stig_id` already exists.

### `SeedHelpers.seed_component(**opts)`

Find or create a Component with all required attributes. Idempotent via `find_or_initialize_by(project, name, version, release)`.

Required keys: `project:`, `name:`, `title:`, `prefix:`, `based_on:` (SRG record).
Optional: `version:` (default 1), `release:` (default 1), plus any Component column.

### `SeedHelpers.find_or_seed_review(rule:, user:, section:, comment:, **extra)`

Create a top-level comment Review. Idempotent — finds existing by `comment` text. Sets `action: 'comment'` automatically.

### `SeedHelpers.find_or_seed_reply(parent:, user:, comment:)`

Create a reply to an existing comment. Idempotent — finds by `responding_to_review_id` + `comment` text. Inherits `section` from parent.

### `SeedHelpers.seed_triage(review, user:, status:)`

Set triage status on a review. Skips if already at the target status. Auto-sets `adjudicated_at` for terminal statuses (duplicate, informational, withdrawn).

### `SeedHelpers.status_report`

Returns a Hash of model counts: `{ users: N, projects: N, srgs: N, ... }`.

### `SeedHelpers.quiet { ... }`

Suppresses `ActionMailer::Base.perform_deliveries` during the block. Prevents Devise from sending confirmation/unlock emails during seeding. Restores the original setting even if the block raises.

### `SeedHelpers.load_threads(path = 'db/seeds/data/threads.yml')`

Loads thread definitions from YAML and normalizes keys/values for `seed_thread` compatibility. Keys become symbols, `rule`/`author`/`by` values become symbols, `comment`/`section`/`status` stay strings.

### `SeedHelpers.cleanup_orphaned_reviews!`

Deletes Review records whose `commentable_id` references a Component that no longer exists. Returns the count of deleted records.

### `SeedHelpers.verify!`

Returns an Array of error strings. Empty array means all checks pass. Checks: admin user exists, project count, SRG count, component count, RBAC coverage on demo projects, comment count, triage status coverage.

## SeedContext

`SeedContext` (`lib/seed_context.rb`) pre-loads all users, projects, and components into indexed hashes for O(1) lookups. Used by `10_comments.rb` to resolve users by symbol key (`:viewer`, `:stig_author`) without repeated database queries.

```ruby
ctx = SeedContext.new
ctx.user(:viewer)                    # User with email viewer@example.com
ctx.user('admin@example.com')        # User by email string
ctx.project('Container Platform')    # Project by name
ctx.component('Container Platform')  # Component by name
ctx.rules_for(component)             # { rule_a: Rule, rule_b: Rule, ... }
```

## threads.yml

Comment thread definitions as YAML data (Chatwoot-inspired pattern). Each thread specifies: `rule` (symbol key), `section`, `author` (symbol key), `comment` text, optional `triage` action, optional `replies` array.

```yaml
rule_threads:
  - rule: rule_a
    section: check_content
    author: viewer
    comment: >-
      The check says "verify TLS 1.2 or greater..."
    replies:
      - author: author
        comment: >-
          We will add an example using openssl s_client...
```

## Adding a New Seed File

1. Create a numbered file in `db/seeds/data/` — pick a number that respects dependencies (users before memberships, SRGs before components, etc.)
2. Use `SeedHelpers` methods for idempotent creation
3. For Review/comment data, use `SeedHelpers.find_or_seed_review` (uses `Review.create!`, plain ActiveRecord)
4. Add progress output with `puts`
5. Test idempotency: run `rails db:seed` twice, verify `rails dev:status` shows the same counts
6. Update `SeedHelpers.verify!` if your seed adds data that should be checked

## Demo Users

All demo users share the password from `VULCAN_SEED_ADMIN_PASSWORD` (default: `12qwaszx!@QWASZX`).

| Email | Role | Purpose |
|-------|------|---------|
| `admin@example.com` | Site admin | Full access, triage, admin actions |
| `viewer@example.com` | Viewer | Can comment, cannot triage |
| `author@example.com` | Author | Can comment + triage |
| `reviewer@example.com` | Reviewer | Can comment + triage + review |

### Community SME Personas

Seeded by `00_users.rb` from `SeedHelpers::COMMUNITY_PERSONAS`. All share the same password. Memberships assigned in `05_memberships.rb`.

| Email | Name | Role |
|-------|------|------|
| `container-sme@example.org` | Container Security SME | Viewer |
| `platform-eng@example.org` | Platform Engineer | Viewer |
| `compliance-analyst@example.org` | Compliance Analyst | Viewer |
| `stig-author@example.org` | STIG Author | Author |
| `security-reviewer@example.org` | Security Reviewer | Reviewer |
| `qa-reviewer@example.org` | QA Reviewer | Reviewer |
| `infra-eng@example.org` | Infrastructure Engineer | Viewer |
| `devsecops@example.org` | DevSecOps Engineer | Author |

## Updating SRG/STIG Seed Data

To update the XCCDF files used for seeding:

1. Download new ZIP from [DISA STIG Library](https://public.cyber.mil/stigs/downloads/)
2. Extract the `*-xccdf.xml` file
3. Replace the corresponding file in `db/seeds/srgs/` or `db/seeds/stigs/`
4. Run `rails db:seed` to import
5. Update any hardcoded assertions in `spec/config/seed_idempotency_spec.rb` if file names changed

To pull the latest STIGs/SRGs from cyber.mil automatically:

```bash
rails stig_and_srg_puller:pull
```
