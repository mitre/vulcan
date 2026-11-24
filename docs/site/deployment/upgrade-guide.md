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
```

Each version can declare:
- **`migration_floor`** — migration timestamp that identifies this version
- **`infrastructure`** — pre-boot changes. Two step types are implemented:
  `db_rename` (applied by the runner) and `env_removed` (advisory — it warns
  when the removed variable is still set, and you edit `.env` yourself)
- **`required_stop`** — documentary only today. `Upgrade::Preflight` does not
  read this key, so marking a version a required stop changes nothing the
  tooling does; it records the intent for whoever reads the manifest.

Data fixes belong in Rails migrations, not in the manifest. `config/upgrade_path.yml`
says so in its own header, and the preflight handles no `data` step type.

### Three-Phase Execution

1. **Infrastructure** (shell, before Rails boots) — `bin/db-rename-legacy` handles database renames. Runs in the Docker entrypoint before `db:prepare`.
2. **Schema** (Rails migrations) — `db:prepare` runs pending migrations as usual, including data-backfill migrations.
3. **Verification** (rake task, after schema is current) — `upgrade:auto` re-runs the preflight, applies any remaining infrastructure actions idempotently, and reports env-var advisories.

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

`docker compose pull` needs a published image, so set `IMAGE_NAME` in your `.env` first (for
example `IMAGE_NAME=mitre/vulcan:release-latest`). Without it the `web` service builds from the
repository instead of pulling.

The entrypoint runs in order:
1. `bin/db-rename-legacy` — renames legacy databases (instant metadata operation)
2. `db:prepare` — creates DB if missing, runs pending migrations
3. `upgrade:auto` — re-checks the upgrade path and reports anything left to do

### Bare Metal

Fetch the release tag you are upgrading to — the tags are listed on the
[releases page](https://github.com/mitre/vulcan/releases), and release tags
carry a leading `v`:

```bash
git fetch --tags origin
git checkout "v${VULCAN_VERSION}"     # e.g. VULCAN_VERSION=2.4.2
bundle install
yarn install && yarn build
bundle exec rake upgrade:preflight    # Review what will change
bundle exec rake upgrade:fix          # Apply infrastructure fixes
bundle exec rake db:prepare           # Run migrations
bundle exec rake upgrade:verify       # Confirm success
```

This sequence assumes your Ruby, Bundler and Yarn already match what the
release pins. **Check that first** — see the version-specific section for the
release you are moving to, and the toolchain note below.

#### Toolchain prerequisites (bare metal)

`bundle install` and `yarn install` both fail outright when the host toolchain
is older than the release pins, and the failure messages do not say to
reinstall anything. Check all three before the steps above. Read the pinned
versions out of the repository rather than from this page, so these commands
stay correct across releases:

```bash
# Ruby — the Gemfile's `ruby` line must match .ruby-version, and `bundle
# install` refuses to run against anything else:
#   "Your Ruby version is X, but your Gemfile specified Y"
cat .ruby-version
ruby -v
# If they differ, install that Ruby with your version manager and re-shim
# before continuing.

# Bundler — the version that wrote Gemfile.lock:
tail -2 Gemfile.lock          # the line under "BUNDLED WITH"
bundler --version
# If they differ: gem install bundler -v <that version>
# A major-version difference matters; Bundler 2 cannot read a Bundler 4 lock.

# Yarn — the pinned package manager:
grep packageManager package.json
yarn --version
# Install the matching release (Corepack: `corepack enable && corepack
# install`). The install flag differs by major version: Yarn 1 takes
# `--frozen-lockfile`, Yarn 2+ takes `--immutable`. `yarn install` with no
# flag works on both.
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

The upgrade system handles jumps across multiple versions: the preflight walks
every version in the manifest and the runner applies each outstanding
infrastructure action in order, so you do not have to stop at intermediate
releases.

Example: upgrading from v2.2.0 when v2.4.0 carries infrastructure changes:
1. Preflight detects the current version as 2.2.0 (from the migration floor)
2. Collects v2.4.0's outstanding infrastructure actions (the DB renames)
3. `upgrade:fix` applies them before `db:prepare` runs the newer migrations

Users running very old versions (v2.0.0, v2.2.0) will see all accumulated changes applied in sequence.

::: warning `required_stop` is not enforced
The preflight does not read `required_stop`, and nothing populates the
report's `blockers` list, so no version can actually halt an upgrade today
and `upgrade:auto`'s "resolve blockers before starting" path is unreachable.
Read a `required_stop: true` entry in the manifest as a note to the operator,
not as a gate the tooling will enforce for you.
:::

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
       - type: env_removed
         var: OLD_VARIABLE
         replacement: NEW_VARIABLE
   ```

2. Put data fixes in a Rails migration, not in the manifest — the manifest
   has no executable step type for them.

3. `required_stop: true` is documentation only until the preflight learns to
   read it; see the warning above.

4. The existing `Upgrade::Preflight` and `Upgrade::Runner` services handle
   `db_rename` and `env_removed` — no Ruby code changes needed for a new
   version that uses only those.

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
- **Fail loud** — a failed action is reported, never swallowed. (The blocker mechanism that
  would halt an upgrade outright is declared but not yet implemented — see the warning under
  [Multi-Version Jumps](#multi-version-jumps).)

## Upgrading to v2.5.0

### Toolchain (bare metal only)

This release moves its pinned Ruby, Bundler and Yarn versions. Docker
deployments get all three inside the image and need to do nothing. On bare
metal, run the three checks under
[Toolchain prerequisites](#toolchain-prerequisites-bare-metal) **before**
`bundle install`, in this order:

1. Install the Ruby in `.ruby-version` and make it the active one
2. `gem install bundler -v <the version under "BUNDLED WITH" in Gemfile.lock>`
3. Install the Yarn in `package.json`'s `packageManager`

Skipping step 1 stops the upgrade at its first command with
`Your Ruby version is ..., but your Gemfile specified ...`, and the earlier
procedure never said to reinstall Ruby.

### Production environment files: nothing to do

`.env.production.example` changed in this release, but only by **removing**
variables that nothing reads:

- `CIPHER_PASSWORD` and `CIPHER_SALT` — no application code ever read them
- `RAILS_LOG_TO_STDOUT` and `RAILS_SERVE_STATIC_FILES` — Rails logs to stdout
  and serves static files unconditionally in production

No variable was added, renamed, or given a new default. Leaving those four in
your existing `.env` is harmless; deleting them changes nothing. **Production
operators have no env-file work for this release** — there is nothing to hunt
for.

### Removed: `POSTGRES_PORT`

Development only. `docker-compose.dev.yml` now publishes the database on
`DATABASE_PORT`, the same variable `config/database.yml` connects to, so one
value configures both. Delete `POSTGRES_PORT` from your `.env`; it is ignored.
See [port registry](/development/port-registry).

### `COVERAGE=true` now works

Development only. `COVERAGE=true` turns SimpleCov on without the rest of what
`CI=true` implies. It was documented long before anything read it.

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

The development database port moved into the port registry so several MITRE
projects can share a host. `docker-compose.dev.yml` briefly published a
separate `POSTGRES_PORT` (default 5435) while Rails kept reading
`DATABASE_PORT` (default 5432); both now read `DATABASE_PORT`, so set that one
variable and delete any `POSTGRES_PORT` from `.env`. See
[port registry](/development/port-registry) for multi-project assignments.

### Personal Access Tokens

New feature: API authentication via Personal Access Tokens. Enabled by default. See [API Authentication](/api/authentication).
