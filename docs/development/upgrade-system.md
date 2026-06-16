# Upgrade System (Developer Guide)

How Vulcan's upgrade infrastructure works and how to extend it for new versions.

## Overview

The upgrade system has three components:

| Component | File | Purpose |
|---|---|---|
| Manifest | `config/upgrade_path.yml` | Declares versions + changes (data, not code) |
| Preflight | `app/services/upgrade/preflight.rb` | Detects current state, builds action plan |
| Runner | `app/services/upgrade/runner.rb` | Executes actions (idempotent) |

Rake tasks (`lib/tasks/upgrade.rake`) provide the CLI. Shell script (`bin/db-rename-legacy`) handles the pre-boot chicken-and-egg case.

## Pattern Origins

| Pattern | Source | What we use it for |
|---|---|---|
| Version manifest YAML | GitLab CE `config/upgrade_path.yml` | Declaring required stops + per-version changes |
| Schema-based detection | Mastodon `ActiveRecord::Migrator.current_version` | Determining current version from `schema_migrations` |
| Entrypoint infrastructure | GitLab/Mastodon/Discourse consensus | DB renames before Rails boots |
| Idempotent actions | All three projects | Safe to re-run on every boot |

## Adding a New Version

When you ship a version with breaking changes:

### 1. Add a manifest entry

```yaml
# config/upgrade_path.yml
2.5.0:
  migration_floor: '20260801000000'    # Your version's first migration timestamp
  required_stop: true                  # Set if skipping this version would break upgrades
  infrastructure:
    - type: db_rename                  # Pre-boot: rename a database
      from: old_name
      to: new_name
    - type: env_removed               # Advisory: env var was removed
      var: OLD_VAR
      replacement: NEW_VAR
  data:
    - type: backfill                   # Post-migration: fix data
      description: Human-readable reason
      sql: "UPDATE table SET col = val WHERE condition"
```

### 2. Write a test

```ruby
# spec/services/upgrade/preflight_spec.rb
it 'detects v2.5.0 infrastructure changes' do
  manifest = {
    '2.4.0' => { 'migration_floor' => '20260530010000' },
    '2.5.0' => {
      'migration_floor' => '20260801000000',
      'infrastructure' => [
        { 'type' => 'db_rename', 'from' => 'old', 'to' => 'new' }
      ]
    }
  }
  report = Upgrade::Preflight.call(manifest_override: manifest)
  # Assert the action is detected
end
```

### 3. That's it

No Ruby code changes needed. The manifest is the only thing you update for standard infrastructure/data changes. If you need a new action type (not `db_rename` or `env_removed`), add a handler to `Upgrade::Runner#execute_actions`.

## How Version Detection Works

```
schema_migrations table
  → MAX(version) = '20260530010000'

config/upgrade_path.yml
  2.0.0:  migration_floor: '20200511155346'  ← matches (floor ≤ max)
  2.3.1:  migration_floor: '20250219042932'  ← matches
  2.3.4:  migration_floor: '20250322160000'  ← matches
  2.3.7:  migration_floor: '20260526130100'  ← matches
  2.4.0:  migration_floor: '20260530010000'  ← matches (highest)

Result: current_version = '2.4.0'
```

The last version whose `migration_floor` is ≤ the latest migration timestamp is the current version. This works regardless of the VERSION file contents.

## The Chicken-and-Egg Problem

When `database.yml` expects `vulcan_development` but the actual database is still named `vulcan_vue_development`, Rails can't boot — it fails with `NoDatabaseError` before any rake task can run.

Solution: `bin/db-rename-legacy` is a **shell script** that runs before Rails. It connects to the `postgres` maintenance database (which always exists) and renames the application databases. This runs in:
- `bin/docker-entrypoint` — before `db:prepare`
- `bin/setup` — before `db:prepare`

The Ruby-based `Upgrade::Runner` handles the same renames but requires Rails to be booted. Both are idempotent — if the rename already happened, they skip silently.

## Testing

```bash
bundle exec rspec spec/services/upgrade/        # Preflight + Runner (13 tests)
bundle exec rspec spec/lib/tasks/upgrade_rake_spec.rb  # Rake tasks (3 tests)
```

Tests create and drop real temporary databases (named with `Process.pid` to avoid collisions). They verify:
- Legacy DB detection and rename
- Idempotency (second run is a no-op)
- Blocker halting
- Both-exist warning
- Version detection from migration floors
- Manifest parsing and Gem::Version compatibility

## File Map

```
config/upgrade_path.yml                     # Version manifest
app/services/upgrade/preflight.rb           # State detection
app/services/upgrade/runner.rb              # Action execution
lib/tasks/upgrade.rake                      # CLI (preflight/fix/verify/auto)
bin/db-rename-legacy                        # Shell pre-boot rename
bin/docker-entrypoint                       # Docker: rename → prepare → auto
bin/setup                                   # Dev: rename → prepare → auto
docs/deployment/upgrade-guide.md            # User-facing upgrade docs
docs/development/upgrade-system.md          # This file (developer docs)
spec/services/upgrade/preflight_spec.rb     # 9 tests
spec/services/upgrade/runner_spec.rb        # 4 tests
spec/lib/tasks/upgrade_rake_spec.rb         # 3 tests
```
