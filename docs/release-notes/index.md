# Release Notes

All Vulcan releases with changelogs and migration notes.

## Current Release

- **[v2.3.1](v2.3.1)** — Per-section rule locking, field state visualization, export modal UX, JSON archive backup/restore

## Previous Releases

- **[v2.2.1](v2.2.1)** — Account lockout (STIG AC-07), classification banner, consent modal, password policy, admin user management
- **[v2.2.0](v2.2.0)** — Rails 8 upgrade, request spec migration, MDI to Bootstrap icons migration

## Upgrade Notes

When upgrading between versions:

1. **Read the release notes** for your target version
2. **Run database migrations**: `bundle exec rails db:migrate`
3. **Rebuild assets**: `yarn install && yarn build`
4. **Run tests**: `bundle exec parallel_rspec spec/ && yarn test:unit`

For Docker deployments, pull the new image and restart. Migrations run automatically via `db:prepare` in the entrypoint.
