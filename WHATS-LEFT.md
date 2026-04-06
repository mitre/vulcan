# What's Left — fix/oidc-provider-conflict branch

**Epic card:** vulcan-v3.x-71q
**Branch:** fix/oidc-provider-conflict (off master)
**3 commits pushed, all tests passing (90 backend + 54 frontend)**

## Done (committed)

### Commit 1: `ec54cf1` — Core OIDC fix
- Symbol/string provider comparison fix (`:oidc` vs `"oidc"`)
- Provider+uid-first lookup in `from_omniauth` (GitLab pattern)
- `rescue_from` ordering (StandardError first = checked last)
- `VULCAN_AUTO_LINK_USER` global setting
- `email_verified` security check for auto-link
- `just_auto_linked?` transient flag (no duplicate email lookup)
- Genericize `oauth_error` flash (no exception leakage)
- Remove unnecessary `save!` on re-auth path
- Replace `gitlab_omniauth-ldap` → `omniauth-ldap` 2.3.3
- Remove `nkf` gem, lazy-load LDAP
- 75 backend auth specs

### Commit 2: `b241334` — Session tracking + profile UX + unlink
- `session[:auth_method]` tracks login method per session
- Profile shows "Signed in via X" + "Account linked to Y" separately
- `POST /users/unlink_identity` with password verification
- Unlink button with confirmation modal (matching app button patterns)
- Audit comments for link/unlink events
- History component suppresses raw changes when comment present
- My Activity filter bug fix (VulcanAudit#format missing `user_id`)
- 15 backend + 29 frontend tests

### Commit 3: `aeb3a55` — Pre-existing bugs + infrastructure
- `vulcan_audit.rb`: bitwise `&` → `&&` crash fix
- `users_controller`: Slack notification gated on `saved_change_to_admin?`
- `registrations_controller`: polymorphic audit query + `user_type`
- Ruby 3.4.8 → 3.4.9
- `parallel_sync.rake`: `TEST_ENV_NUMBER` recursion guard
- `docker-compose.dev.yml`: `POSTGRES_HOST_AUTH_METHOD: trust` (VPN compat)

## Pending bug-scan fixes (need TDD)

| Card | Priority | File | Issue |
|------|----------|------|-------|
| 71q.3 | P1 | registrations_controller.rb | `prev_unconfirmed_email` dropped (breaks reconfirmation flash) |
| 71q.4 | P2 | users_controller.rb | `update!` on reset token runs validations (should be `update_columns`) |
| 71q.5 | P2 | users_controller.rb | Swallowed `StandardError` leaks `e.message` to client |
| 71q.7 | P2 | UserProfile.vue | Dead `authProvider` computed property (remove) |
| 71q.8 | P3 | user.rb + callbacks | Backtrace only logged in development |
| 71q.9 | P3 | user.rb | `email_verified` string coercion (use Boolean cast) |
| 71q.10 | P3 | UsersTable.vue | Strict-null check may mishandle `undefined` |
| 71q.11 | P3 | project_member_constants.rb | `PROJECT_MEMBER_ADMINS` naming inconsistency |
| 71q.12 | P4 | registrations_controller.rb | Document `valid_password?` bcrypt→PBKDF2 side-effect |

**Dependency chains** (do in order to avoid merge conflicts):
- `registrations_controller.rb`: 71q.3 → 71q.12
- `users_controller.rb`: 71q.4 → 71q.5
- `user.rb`: 71q.8 → 71q.9

## Future features (not blocking this PR)

| Card | Priority | Description |
|------|----------|-------------|
| 71q.13 | P2 | Profile "Link with provider" button (symmetry with unlink) |
| 71q.14 | P2 | Lockout on repeated bad unlink attempts (wire into Devise lockable) |

## Research (documented in cards)

| Card | Topic |
|------|-------|
| 71q.15 | OmniAuth provider lookup patterns (GitLab, Discourse) |
| 71q.16 | OrbStack + GlobalProtect VPN routing conflicts |
| 71q.17 | GitHub Actions supply chain hardening (tj-actions) |

## Heroku env vars already set

- `VULCAN_AUTO_LINK_USER=true` on staging, prod, training
- Okta OIDC credentials on staging (trial-8371755.okta.com)
- Review apps inherit via `app.json`

## To push for review

```bash
git push -u origin fix/oidc-provider-conflict
gh pr create --base master --title "fix: OIDC provider conflict + auth UX" --body "..."
```
