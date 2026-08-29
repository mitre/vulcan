# Release Notes

All Vulcan releases with changelogs and migration notes.

## Current Release

- **[v2.4.2](v2.4.2)** — Full SRG-component export and spreadsheet re-import parity with STIG components, a project-page component lock indicator, and session-timeout fixes (restored the 1-hour default that had been dropped to 10 minutes; corrected `VULCAN_SESSION_TIMEOUT`/`VULCAN_REMEMBER_ME_DURATION` suffix parsing).

## Previous Releases

- **[v2.4.1](v2.4.1)** — Redesigned three-column comment-triage split-pane with a click-to-filter progress bar and accessibility landmarks, SRG-authoring foundations (persisted minted-identifier sequence), login-path security hardening (JSON login lockout + throttling, server-side local-login guard), and a broad set of fixes. **Self-hosted: the 2.4 line standardizes database names (`DB_SUFFIX` → `DATABASE_NAME`) — read the upgrade notes.**

- **[v2.3.7](v2.3.7)** — Component-level comments via polymorphic reviews, project-aggregate disposition matrix CSV export, "Comment" toolbar rename, replies allowed on active threads after the comment period closes, vocabulary refresh ("Overall Requirement" replaces "(general)").
- **[v2.3.6](v2.3.6)** — UBI9 base image (Iron Bank / DISA-aligned), public-comment-review workflow with triage + adjudication, viewer-can-comment, comment reactions (👍/👎), structured 403s with admin contacts. **Includes breaking Docker / Compose volume changes — read the release notes before upgrading.**
- **[v2.3.5](v2.3.5)** — Server-side user search (information disclosure fix), editor refresh shape drift fix, CI/release workflow split
- **[v2.3.4](v2.3.4)** — Blueprinter JSON serialization, query performance hardening, OIDC fix, auth UX
- **[v2.3.1](v2.3.1)** — Per-section rule locking, field state visualization, export modal UX, JSON archive backup/restore

- **[v2.2.1](v2.2.1)** — Account lockout (STIG AC-07), classification banner, consent modal, password policy, admin user management
- **[v2.2.0](v2.2.0)** — Rails 8 upgrade, request spec migration, MDI to Bootstrap icons migration

## Upgrade Notes

When upgrading between versions:

1. **Read the release notes** for your target version
2. **Run database migrations**: `bundle exec rails db:migrate`
3. **Rebuild assets**: `yarn install && yarn build`
4. **Run tests**: `bundle exec parallel_rspec spec/ && yarn test:unit`

For Docker deployments, pull the new image and restart. Migrations run automatically via `db:prepare` in the entrypoint.
