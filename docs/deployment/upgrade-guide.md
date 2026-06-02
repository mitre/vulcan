# Upgrade Guide

Vulcan includes a data-driven upgrade system that detects your current version, identifies what needs to change, and applies safe fixes automatically. The system follows patterns from [GitLab CE](https://docs.gitlab.com/ee/update/#upgrade-paths) (version manifest) and [Mastodon](https://github.com/mastodon/mastodon/blob/main/lib/mastodon/cli/maintenance.rb) (schema-based version detection).

## How It Works

### Version Detection

Vulcan determines your current version by checking `schema_migrations` — the actual database state, not a VERSION file. Each version in `config/upgrade_path.yml` declares a `migration_floor` (the earliest migration timestamp that proves that version is installed). The highest matching floor is your current version.

### Upgrade Path Manifest

`config/upgrade_path.yml` is the source of truth for all version-specific changes:

```yaml
# Example entry
2.4.0:
  migration_floor: '20260530010000'
  required_stop: true
  infrastructure:
    - type: db_rename
      from: vulcan_vue_development
      to: vulcan_development
    - type: env_removed
      var: DB_SUFFIX
      replacement: DATABASE_NAME
  data:
    - type: backfill
      description: Set NULL visibility to hidden (default)
      sql: "UPDATE projects SET visibility = 1 WHERE visibility IS NULL"
```

Each version can declare:
- **`migration_floor`** — migration timestamp that identifies this version
- **`required_stop`** — if true, upgrades MUST pass through this version (can't skip)
- **`infrastructure`** — pre-boot changes (DB renames, env var migrations)
- **`data`** — post-migration data fixes (backfills, cleanups)

### Three-Phase Execution

1. **Infrastructure** (shell, before Rails boots) — `bin/db-rename-legacy` handles database renames. Runs in the Docker entrypoint before `db:prepare`.
2. **Schema** (Rails migrations) — `db:prepare` runs pending migrations as usual.
3. **Data** (rake tasks, after schema is current) — `upgrade:auto` applies backfills and data fixes.

## Upgrade Commands

### `rake upgrade:preflight` — What would happen?

Read-only diagnostic. Shows your current version, pending versions, actions that need to be applied, and any warnings or blockers. Safe to run anytime.

```bash
$ bundle exec rake upgrade:preflight

============================================================
Upgrade preflight report
============================================================
Current version: 2.3.7
Pending versions: 2.4.0

Actions to apply (3):
  → Rename database: vulcan_vue_development → vulcan_development (v2.4.0)
  → Rename database: vulcan_vue_test → vulcan_test (v2.4.0)
  → Rename database: vulcan_postgres_production → vulcan_production (v2.4.0)
```

### `rake upgrade:fix` — Apply fixes

Executes all safe, auto-fixable actions from the preflight report. Idempotent — running it twice produces no errors.

```bash
$ bundle exec rake upgrade:fix

Applying 3 upgrade action(s)...
  ✔ Applied: db_rename vulcan_vue_development→vulcan_development
  ✔ Applied: db_rename vulcan_vue_test→vulcan_test
  ✔ Applied: db_rename vulcan_postgres_production→vulcan_production
Upgrade fix complete.
```

### `rake upgrade:verify` — Post-upgrade validation

Checks that all migrations are applied, no legacy database names remain, and deprecated env vars are cleared.

```bash
$ bundle exec rake upgrade:verify

============================================================
Upgrade verification
============================================================
All checks passed.
```

### `rake upgrade:auto` — Entrypoint shortcut

Runs preflight + fix in one shot. Silent when nothing to do. Exits with code 1 on blockers or errors. Used by `bin/docker-entrypoint` and `bin/setup`.

## Upgrade Procedures

### Docker Deployments

Upgrades are fully automatic. Pull the new image and restart:

```bash
docker compose pull web
docker compose up -d web
```

The entrypoint runs in order:
1. `bin/db-rename-legacy` — renames legacy databases (instant metadata operation)
2. `db:prepare` — creates DB if missing, runs pending migrations
3. `upgrade:auto` — applies data fixes

### Bare Metal

```bash
git pull origin v2.4.0
bundle install
yarn install --frozen-lockfile && yarn build
bundle exec rake upgrade:preflight    # Review what will change
bundle exec rake upgrade:fix          # Apply infrastructure fixes
bundle exec rake db:prepare           # Run migrations
bundle exec rake upgrade:verify       # Confirm success
```

### Local Development

```bash
bin/setup    # Handles everything: db-rename-legacy → db:prepare → upgrade:auto
```

Or manually:

```bash
bin/db-rename-legacy                  # Rename legacy DBs
bundle exec rake db:prepare           # Migrations
bundle exec rake upgrade:auto         # Data fixes
```

## Multi-Version Jumps

The upgrade system handles jumps across multiple versions. If a version is marked `required_stop: true`, the preflight will report it and the runner will apply all intermediate steps in order.

Example: upgrading from v2.2.0 to v2.5.0 when v2.4.0 is a required stop:
1. Preflight detects current version as 2.2.0 (from migration floor)
2. Identifies v2.4.0 as a required stop with infrastructure changes
3. Applies v2.4.0 infrastructure (DB renames) before v2.5.0 migrations

Users running very old versions (v2.0.0, v2.2.0) will see all accumulated changes applied in sequence.

## Adding Future Upgrade Steps

When a new version introduces breaking changes:

1. Add an entry to `config/upgrade_path.yml`:
   ```yaml
   2.5.0:
     migration_floor: '20260801000000'
     infrastructure:
       - type: db_rename
         from: old_name
         to: new_name
     data:
       - type: backfill
         description: What this fixes
         sql: "UPDATE table SET column = value WHERE condition"
   ```

2. If this version can't be skipped, add `required_stop: true`

3. The existing `Upgrade::Preflight` and `Upgrade::Runner` services handle the rest — no Ruby code changes needed for new versions.

## Architecture

```
config/upgrade_path.yml          ← Data (versions + changes)
        │
app/services/upgrade/
  preflight.rb                   ← Read-only state detection
  runner.rb                      ← Action execution (idempotent)
        │
lib/tasks/upgrade.rake           ← CLI interface (preflight/fix/verify/auto)
        │
bin/db-rename-legacy             ← Shell fallback (pre-boot DB renames)
bin/docker-entrypoint            ← Calls db-rename-legacy → db:prepare → upgrade:auto
bin/setup                        ← Same sequence for local dev
```

### Design Principles

- **Data, not code** — version-specific changes go in YAML, not scattered across rake tasks
- **Schema-based detection** — current version determined from `schema_migrations`, not a VERSION file
- **Idempotent** — every operation is safe to run multiple times
- **Infrastructure before boot** — DB renames in shell (can't boot Rails if DB has wrong name)
- **Fail loud** — blockers halt the upgrade with a clear message, don't silently continue

## Upgrading to v2.4.0

### Database Naming Standardization

| Old Name | New Name |
|---|---|
| `vulcan_vue_development` | `vulcan_development` |
| `vulcan_vue_test` | `vulcan_test` |
| `vulcan_postgres_production` | `vulcan_production` |

This rename is handled automatically by `bin/db-rename-legacy` and `upgrade:fix`. `ALTER DATABASE RENAME` is a PostgreSQL metadata operation — instant, no data copy.

### Removed: `DB_SUFFIX`

The `DB_SUFFIX` environment variable for git worktree database isolation has been removed. Use `DATABASE_NAME` to override the database name if needed.

### Port Registry

Default database port in `docker-compose.dev.yml` changed from `5432` to `5435`. Set `DATABASE_PORT` and `POSTGRES_PORT` in your `.env` — see [port registry](/development/port-registry) for multi-project assignments.

### Personal Access Tokens

New feature: API authentication via Personal Access Tokens. Enabled by default. See [API Authentication](/api/authentication).
