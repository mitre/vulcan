# Test & Development Account Safety

How Vulcan ensures test/development accounts never appear in production.

## Architecture: Two-Concern Seed Pattern

Vulcan follows the [GitLab/ThoughtBot two-concern pattern](https://thoughtbot.com/blog/clean-database-seeding):

- **Production seeds** (SRGs, STIGs, admin bootstrap) run on every deploy via `db:prepare`
- **Demo data** (users, projects, comments) is dev-only, gated by `Rails.env.local?`

## Production Safety Guards

### 1. `db/seeds.rb` — Environment Gate

```ruby
unless Rails.env.local? || ENV['VULCAN_SEED_DEMO_DATA'] == 'true'
  puts 'Skipping seed data...'
  return
end
```

Seeds are **skipped** in production. The `VULCAN_SEED_DEMO_DATA=true` escape hatch exists for training/demo instances — it requires explicit opt-in.

### 2. Docker Entrypoint — No `db:seed`

`bin/docker-entrypoint` runs:
- `db:prepare` (creates DB if missing, runs migrations)
- `upgrade:auto` (data-level fixes)

It does **NOT** run `db:seed`. Demo data is never created automatically in production containers.

### 3. Admin Bootstrap — Env-Var-Driven

`lib/tasks/admin_bootstrap.rake` creates the initial admin from `VULCAN_ADMIN_EMAIL` + `VULCAN_ADMIN_PASSWORD` environment variables. No hardcoded credentials. Skips if any admin already exists.

### 4. First-User-Admin — Advisory-Locked

The `User` model's `after_create` callback promotes the first user to admin when `VULCAN_FIRST_USER_ADMIN=true`. Uses PostgreSQL advisory lock to prevent race conditions. Only fires when zero admins exist.

### 5. Factory Accounts — Generated Sequences

`spec/factories/users.rb` uses `generate(:email)` and `generate(:password)` — no hardcoded credentials. Factories are only loaded in test environment (`spec/` is not in the production load path).

## Demo Account Inventory

All demo accounts use RFC 2606 reserved domains (`@example.com`, `@example.org`) which cannot conflict with real email addresses.

| Email | Role | Created By | Environment |
|-------|------|-----------|-------------|
| `admin@example.com` | Admin | `db/seeds/data/00_users.rb` | Dev only |
| `viewer@example.com` | Viewer tier | `db/seeds/data/00_users.rb` | Dev only |
| `author@example.com` | Author tier | `db/seeds/data/00_users.rb` | Dev only |
| `reviewer@example.com` | Reviewer tier | `db/seeds/data/00_users.rb` | Dev only |
| `container-sme@example.org` | Viewer (SME) | `db/seeds/data/00_users.rb` | Dev only |
| `platform-eng@example.org` | Viewer | `db/seeds/data/00_users.rb` | Dev only |
| `compliance-analyst@example.org` | Viewer | `db/seeds/data/00_users.rb` | Dev only |
| `stig-author@example.org` | Author | `db/seeds/data/00_users.rb` | Dev only |
| `security-reviewer@example.org` | Reviewer | `db/seeds/data/00_users.rb` | Dev only |
| `qa-reviewer@example.org` | Reviewer | `db/seeds/data/00_users.rb` | Dev only |
| `infra-eng@example.org` | Viewer | `db/seeds/data/00_users.rb` | Dev only |
| `devsecops@example.org` | Author | `db/seeds/data/00_users.rb` | Dev only |
| 10 filler users | Non-admin | `db/seeds/data/00_users.rb` | Dev only |

**Default password**: `12qwaszx!@QWASZX` (overridable via `VULCAN_SEED_ADMIN_PASSWORD` env var). Only used in development — never reachable in production without explicit `VULCAN_SEED_DEMO_DATA=true`.

## What Could Go Wrong (and Why It Won't)

| Scenario | Guard |
|----------|-------|
| `db:seed` runs in production accidentally | `Rails.env.local?` gate returns early |
| Docker container creates demo users | Entrypoint runs `db:prepare`, not `db:seed` |
| Admin created with hardcoded password | `admin_bootstrap.rake` uses env vars exclusively |
| Factory accounts leak to production | `spec/` not in production load path, factories require `rails_helper` |
| Demo password used for real admin | Env var `VULCAN_ADMIN_PASSWORD` overrides default; production deployments use `setup-docker-secrets.sh` which generates random secrets |

## Best Practices Comparison

| Pattern | Discourse | GitLab | Vulcan |
|---------|-----------|--------|--------|
| Dev-only seeds gated by env | `Rails.env.development?` | `Gitlab::Seeders` class | `Rails.env.local?` |
| No `db:seed` in production entrypoint | Yes | Yes | Yes |
| Admin from env vars | Yes (via `DISCOURSE_ADMIN_*`) | Yes (via `GITLAB_ROOT_*`) | Yes (via `VULCAN_ADMIN_*`) |
| RFC 2606 domains for test data | Yes | Yes | Yes |
| Factory sequences (no hardcoded creds) | Yes | Yes | Yes |
