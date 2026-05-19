# Seed System

Vulcan's seed system follows the [GitLab/ThoughtBot two-concern pattern](https://thoughtbot.com/blog/priming-the-pump): production-required data (admin bootstrap, SRGs/STIGs) is separate from development demo data (sample users, projects, comments).

## Architecture

```
db/
├── seeds.rb                     # Thin loader — loads db/seeds/data/*.rb in order
└── seeds/
    └── data/
        ├── 00_users.rb          # Admin + role-tier + filler users
        ├── 01_projects.rb       # Demo projects
        ├── 02_srgs.rb           # SRG XCCDF XML imports
        ├── 03_stigs.rb          # STIG XCCDF XML imports
        ├── 04_components.rb     # Named + overlay + dummy components
        ├── 05_memberships.rb    # User → Project RBAC wiring
        ├── 06_rule_statuses.rb  # Varied statuses for demo coverage
        ├── 10_comments.rb       # Container Platform comments (FactoryBot)
        └── 11_cross_project.rb  # Cross-project comments (FactoryBot)
    └── srgs/                    # DISA SRG XCCDF XML files (4)
    └── stigs/                   # DISA STIG XCCDF XML files (4)

lib/
├── seed_helpers.rb              # Shared helpers (SeedHelpers module)
└── tasks/
    └── dev.rake                 # User-facing rake tasks
```

### Design Decisions

- **No seed management gem.** We evaluated seed-fu (unmaintained since 2018), seedbank (2017), and others. The complexity of XCCDF parsing, polymorphic comments, and triage state machines means 80%+ of seeds need custom Ruby. Modular numbered files give the same benefits with zero dependencies.
- **FactoryBot for demo data only.** FactoryBot is used in comment/review seeds (files 10+) and the `dev:prime` rake task. Production seeds (SRGs, admin bootstrap) use plain ActiveRecord — per ThoughtBot's own recommendation.
- **Every seed file is idempotent.** Uses `find_or_create_by`, `find_or_initialize_by`, or `SeedHelpers.find_or_seed_review`. Running `rails db:seed` twice produces identical data.

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

### `SeedHelpers.verify!`

Returns an Array of error strings. Empty array means all checks pass. Checks: admin user exists, project count, SRG count, component count, RBAC coverage on demo projects, comment count, triage status coverage.

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
