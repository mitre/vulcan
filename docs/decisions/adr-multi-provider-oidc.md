# ADR: Multi-Provider OIDC — N Simultaneous Providers

**Status:** Proposed
**Date:** 2026-06-11 (revised 2026-06-13)
**Deciders:** Aaron Lippold
**Card:** v2-hf6q.7 (epic v2-hf6q — login.gov support)

> **Revision 2026-06-13 — identity model.** The original draft kept Vulcan's
> single `users.provider`/`uid` columns and *deferred* a multi-link identity
> table. Aaron decided the same person must be able to authenticate via more
> than one provider (work + personal contexts) under one account, with
> operator visibility into which identities a user has linked. Point 6 is
> rewritten to a first-class `identities` table (multi-link), and a new
> **§6a Verified linking** section adopts the documented account-linking
> security standard (linking always proves control of the existing account;
> email match alone never links). See §Research → "Account-linking security".

## Context

Vulcan has exactly one OIDC slot: a single `Settings.oidc` block registered as
one omniauth strategy named `:oidc`, with `client_auth_method: :secret`
hardcoded. Adding login.gov to a deployment that already uses Okta would
**evict** Okta.

Decision driver (Aaron, 2026-06-11): staging — and any deployment — must be
able to offer Okta **and** login.gov sign-in simultaneously. login.gov
additionally requires `private_key_jwt` client authentication (no client
secrets), so client auth must become a per-provider setting.

Constraints:

- **12-factor / Heroku** — all configuration via environment variables
- **Zero-change backward compatibility** — existing single-provider
  `VULCAN_OIDC_*` deployments keep working unchanged
- **Generalize to N** — no hardcoded second provider
- LDAP and GitHub already coexist as separate strategies; they are untouched

### Current coupling points (audited 2026-06-11)

| Layer | Today | Multi-provider gap |
|---|---|---|
| Config | One `Settings.oidc` block (`vulcan.default.yml`), `client_auth_method: :secret` hardcoded | Needs a providers collection with per-provider auth method + key |
| Registration | `config.omniauth Settings.oidc.strategy, Settings.oidc.args` — one strategy named `:oidc` | Needs N registrations with distinct names |
| Callbacks | `OmniauthCallbacksController#all` + `alias oidc all` — already provider-name driven | Needs an action per strategy name (mechanical) |
| Login page | HAML loops `non_ldap_oauth_providers` but labels every button with the single `oidc_title_text` | Needs per-provider titles |
| Logout | `session[:auth_method]` **already records the signing-in strategy name**; `SessionsController#destroy` reads the global `Settings.oidc.args` | Needs to resolve provider config from `session[:auth_method]` |
| Identity | `users.provider` / `users.uid` single columns; `from_omniauth` hard-blocks a different provider on the same email (`ProviderConflictError`); auto-link only `local → SSO` | One human can't link two providers; needs an `identities` table (multi-link), a `from_omniauth` rewrite, a Connected-Accounts UI, and a backfill migration of existing `provider`/`uid` rows |

## Research

### GitLab — the canonical Rails multi-OIDC pattern

GitLab (Devise + omniauth_openid_connect, same stack) documents multiple
simultaneous OIDC providers as an **array of provider configs**, each with:

- a unique `name` (e.g. `openid_connect`, `openid_connect_2fa`) — the name is
  embedded in the callback URL (`/users/auth/<name>/callback`) and in the
  user's identity record
- explicit `strategy_class: "OmniAuth::Strategies::OpenIDConnect"` so name
  resolution never guesses
- per-provider `client_auth_method` — `basic` (default), `query`,
  `jwt_bearer`, `mtls` — and per-provider credentials in `client_options`

Source: https://docs.gitlab.com/ee/administration/auth/oidc.html

GitLab's identity lesson: the provider **name is the identity key**. Renaming
a provider orphans identities unless rows are migrated. Names must be chosen
deliberately and a rename path must exist.

### Devise mechanics (gem source, verified locally)

`Devise.omniauth(provider, *args)` builds `OmniAuth::Config` where
`strategy_name = options[:name] || provider` and stores the config **keyed by
strategy_name** (`lib/devise.rb`, `lib/devise/omniauth/config.rb`). Therefore:

```ruby
config.omniauth :openid_connect, { name: :okta, ... }
config.omniauth :openid_connect, { name: :login_gov, ... }
```

is first-class Devise: two providers, two routes
(`/users/auth/okta/callback`, `/users/auth/login_gov/callback`), two entries
in `Devise.omniauth_providers`. `strategy_class:` can be passed explicitly
(GitLab does; we will too).

### omniauth_openid_connect

README: "the name configuration exists because you could be using multiple
OpenID Connect providers in a single app." Vulcan already proves the
named-strategy path works with Devise (name `:oidc`, routes
`/users/auth/oidc/...`).

### login.gov

Requires `private_key_jwt` (RSA ≥2048) or PKCE; client secrets are not
supported. rack-oauth2 implements `:jwt_bearer` natively and
omniauth_openid_connect passes `client_auth_method` through (verified in gem
source, Session 39) — **config plumbing, no forks**. login.gov registers ONE
URI list used for both sign-in callback and post-logout redirect.

### Account-linking security (added 2026-06-13)

Multi-link is a well-defined problem with a strong cross-source consensus. The
universal rule: **never link or merge accounts on a matching email alone — the
person linking must prove control of the *existing* account, and the new IdP's
email must be verified.** Email is not a safe link key (recycled, changed,
spoofable); the immutable `(issuer, subject)` pair is.

- **Account pre-hijacking research** (Sudhodanan & Paverd / Microsoft MSRC,
  2022 — 35 of 75 major services vulnerable, incl. Dropbox, Zoom, WordPress):
  the *Classic-Federated Merge* and *Trojan Identifier* classes both stem from
  "the service fails to verify the user actually owns the identifier before
  allowing use of the account." Mitigations: verify identifier ownership
  before merge, require re-authentication at link time, and invalidate other
  sessions on credential/identity changes.
  (https://www.microsoft.com/en-us/msrc/blog/2022/05/pre-hijacking-attacks)
- **Ory — secure account linking**: ranked patterns — (1) *manual /
  user-initiated* linking while signed in (proves both sides) is safest; (2)
  *link-on-login with a verification step* (re-auth the existing account) when
  a new provider matches an existing email; (3) *auto-link by verified email*
  must be **opt-in, default off**, and gated on `email_verified=true`
  ("a gate, not a guarantee"). Link the immutable `(iss, sub)`, not email.
  (https://www.ory.com/blog/secure-account-linking-iam-sso-oidc-saml)
- **OWASP** (Authentication, Email Validation & Verification cheat sheets):
  apply one documented email comparison policy consistently across
  registration, login, reset, recovery, **and linking**; do not auto-merge on
  unverified identifiers.
- **NIST SP 800-63C** (federation; login.gov is 800-63 based): IAL/AAL/FAL
  describe how well-proofed an identity and assertion are. login.gov's
  identity assertions are trustworthy — but that does **not** authorize
  merging a login.gov sign-in into a pre-existing Okta account. The linking
  decision stays Vulcan's and must verify existing-account control regardless
  of the new IdP's strength. (FAL is a per-deployment assertion-security
  setting, orthogonal to the linking design.)

## Decision

### 1. Config shape — provider registry env var + per-provider families

```
VULCAN_OIDC_PROVIDERS=okta,login_gov          # registry: ordered, lowercase snake_case keys

VULCAN_OIDC_OKTA_ISSUER_URL=https://org.okta.com/oauth2/default
VULCAN_OIDC_OKTA_CLIENT_ID=...
VULCAN_OIDC_OKTA_CLIENT_SECRET=...
VULCAN_OIDC_OKTA_TITLE=Okta

VULCAN_OIDC_LOGIN_GOV_ISSUER_URL=https://idp.int.identitysandbox.gov
VULCAN_OIDC_LOGIN_GOV_CLIENT_ID=urn:gov:gsa:openidconnect.profiles:sp:sso:mitre:vulcan-dev
VULCAN_OIDC_LOGIN_GOV_CLIENT_AUTH_METHOD=jwt_bearer
VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY_PATH=/path/to/key.pem   # or _PRIVATE_KEY (inline PEM, for Heroku)
VULCAN_OIDC_LOGIN_GOV_ACR_VALUES=urn:acr.login.gov:auth-only
VULCAN_OIDC_LOGIN_GOV_TITLE=login.gov
```

- The registry key **is** the strategy name, the callback path segment, and
  the `users.provider` value. Choose once, deliberately.
- Every variable in today's single-slot set gets a per-provider form:
  `ISSUER_URL, CLIENT_ID, CLIENT_SECRET, CLIENT_AUTH_METHOD, PRIVATE_KEY,
  PRIVATE_KEY_PATH, ACR_VALUES, TITLE, PROMPT, DISCOVERY, REDIRECT_URI,
  CLIENT_SIGNING_ALG` + the manual endpoint overrides.
- `CLIENT_AUTH_METHOD` accepts `secret` (default) or `jwt_bearer`
  (= login.gov's "private_key_jwt"; rack-oauth2's name for it).
- Surface lands as `Settings.oidc.providers` (a list), generated by an ERB
  loop in `vulcan.default.yml` over `VULCAN_OIDC_PROVIDERS` — one config
  system (Settings), testable via settings specs.

**Rejected:** YAML/JSON blob in a single env var (unmanageable on Heroku);
config-file-only provider list (not 12-factor); per-provider Ruby initializer
constants (second config system).

### 2. Strategy registration — loop in devise.rb

```ruby
Settings.oidc.providers.each do |provider|
  config.omniauth :openid_connect,
                  provider.args.to_h.merge(
                    name: provider.name.to_sym,
                    strategy_class: OmniAuth::Strategies::OpenIDConnect
                  )
end
```

`OmniauthCallbacksController` gains its per-provider actions dynamically —
the same `alias` pattern used today, generated from the configured provider
names (the `all` action is already provider-agnostic).

### 3. Per-provider client auth

`client_auth_method` and key material live on each provider entry. For
`jwt_bearer`, the private key (from `_PRIVATE_KEY` inline PEM or
`_PRIVATE_KEY_PATH`) is loaded into the strategy's client options at
registration. Okta keeps `secret`; login.gov uses `jwt_bearer`. Keys are
never committed; inline PEM exists for Heroku config vars.

### 4. Login page — one button per provider

The sign-in page renders one button per enabled OIDC provider, labeled by
that provider's `TITLE`, inside the existing SSO tab. Helper change:
`oidc_title_text` → `oauth_provider_title(name)` resolving per-provider
settings. (`session[:auth_method]`-driven profile text generalizes the same
way.)

### 5. Logout — resolve provider from the session

`session[:auth_method]` already stores the strategy name at sign-in.
`SessionsController#destroy` resolves **that provider's** settings for
end_session discovery; the Okta-shaped fallback stays gated to Okta-host
issuers (now evaluated per provider). The `/users/signed_out` landing is
shared by all providers — each provider registration must include it as an
allowed post-logout URI (already done for Okta dev and login.gov
dev/staging).

### 6. User identity — `identities` table (multi-link)

One human can legitimately hold several provider identities (work Okta +
personal login.gov + GitHub). Vulcan models that as a first-class
`identities` table, so a single account links N providers and operators can
*see* what a user has linked.

```
identities
  id            bigint pk
  user_id       fk → users (on delete cascade)
  provider      string   # the registry key: okta, login_gov, oidc, ldap, github
  uid           string   # the IdP subject (sub) — immutable identity key
  email         string   # email this IdP asserted (for display/audit; NOT the link key)
  last_sign_in_at datetime
  timestamps
  UNIQUE (provider, uid)
  INDEX (user_id)
```

- `User has_many :identities, dependent: :destroy`; `Identity belongs_to :user`.
- The **link key is `(provider, uid)`** — never email (emails recycle, change,
  spoof; see §Research → Account-linking security).
- `users.provider` / `users.uid` are **kept as a denormalized "last-used
  identity"** so the ~10 existing read sites (sessions, registrations, settings
  nav, lockout, admin user view) need no change; the `identities` table is the
  source of truth for the full set. Every successful sign-in updates both the
  matched identity's `last_sign_in_at` and the denormalized columns.
- **Operator visibility**: the admin user view lists `user.identities`
  (provider + email + last-used) — the "which contexts is this person signed in
  from" picture, backed by audited link/unlink events.

### 6a. Verified linking — security model (REQUIRED)

Linking is a sensitive operation. Per the documented standard, **a matching
email never links by itself; the linker must prove control of the existing
account, and the new IdP's email must be verified.**

- **Default path — explicit "Connect account" while signed in (safest).** From
  Account → Connected Accounts, a signed-in user clicks "Connect login.gov",
  completes that provider's OAuth, and a new `identity` row is created for the
  *current* user. Being signed in proves the existing account; completing OAuth
  proves the new identity. Audited.
- **Cold sign-in via an unlinked provider whose email matches an existing
  account → blocked with guidance, never a silent merge.** Replaces today's
  dead-end `ProviderConflictError` with an actionable message: "An account with
  this email already exists — sign in and connect this provider from Account
  settings." (The pre-hijacking *Classic-Federated Merge* mitigation.)
- **`email_verified` is a gate, not a guarantee.** If a provider asserts
  `email_verified=false` (or omits it), auto-link is refused outright — the
  existing `from_omniauth` guard, kept.
- **`Settings.auto_link_user` stays opt-in (default off)** and applies ONLY to
  `local → SSO` (linking a password account to one SSO identity, gated on
  `email_verified`). It NEVER silently merges `SSO → SSO`; cross-SSO linking is
  always the explicit signed-in Connect flow.
- **Unlink** (Connected Accounts): guarded so a user cannot remove their last
  remaining sign-in method (must keep a password or another identity); the
  unlinked identity's sessions are invalidated; the event is audited (Trojan
  Identifier mitigation).
- **Session hygiene**: a password reset / identity change invalidates other
  sessions (pre-hijacking session-invalidation mitigation).

### 6b. Provider rename path

A documented rake task (`vulcan:auth:rename_provider[old,new]`) updates the
`provider` value on `identities` rows (and the denormalized `users.provider`)
when an operator renames a provider (e.g. legacy `oidc` → `okta`), paired with
registering the new callback URI at the IdP.

### 7. Backward compatibility — legacy vars are a provider named `oidc`

**Config:** when `VULCAN_OIDC_PROVIDERS` is **unset** and
`VULCAN_ENABLE_OIDC=true`, the unprefixed `VULCAN_OIDC_*` variables define a
single provider named `oidc` — same strategy name, same
`/users/auth/oidc/callback` route, same `provider='oidc'` value. **Zero config
change, zero re-registration** for every existing deployment. Explicit
backward-compat spec required.

**Data:** a one-time migration backfills the `identities` table from every
existing user with a non-`local` `provider`/`uid` (one identity row per user,
copying `provider`, `uid`, `email`). Idempotent and reversible. The denormalized
`users.provider`/`uid` columns are left in place. In this dev DB the only
non-local value is `oidc`, so the backfill is small; production may also carry
`okta`/`ldap`/`github`. After backfill, `from_omniauth`'s identity-first lookup
finds returning users by `(provider, uid)` exactly as before — no user
re-links, no forced re-auth.

## Consequences

- login.gov support (private_key_jwt) becomes a per-provider option on a
  stable N-provider foundation — built once, not retrofitted
- Old epic children hf6q.1 (single-slot config surface) and hf6q.2
  (single-slot private_key_jwt wiring) are **subsumed** by this design and
  will be re-carded as phases of the implementation
- Operators get a uniform recipe: add a key to `VULCAN_OIDC_PROVIDERS`, set
  its env family, register two URIs at the IdP
- The sessions/logout code sheds its global-singleton assumption, which also
  fixes the latent "wrong provider's logout" bug class permanently
- One person can link several providers under one account (work + personal
  contexts), and operators gain audited visibility into a user's linked
  identities — at the cost of a larger build than single-column (identities
  table + `from_omniauth` rewrite + Connected-Accounts UI + backfill migration)
- The identity layer adopts the documented account-linking security standard,
  retiring the dead-end `ProviderConflictError` for an actionable
  connect-from-settings path and closing the account-pre-hijacking / takeover
  classes by design

## Implementation Phases (carding plan)

Mapped to epic `v2-hf6q` cards (2026-06-13 re-card). The identity-model
decision adds two cards (`.11` identities table + `from_omniauth`, `.12`
Connected-Accounts UI) and reshapes `.9`/`.10`/`.5`.

1. **Provider registry + settings** (`.1`) — ERB loop, legacy mapping, settings
   specs. Independent of the identity model; can go first/parallel.
2. **N-strategy registration + callbacks + login page** (`.8`) — `devise.rb`
   loop, dynamic callback actions, per-provider buttons, request specs per
   provider. Depends on `.1`.
3. **Per-provider client auth** (`.2`) — `jwt_bearer` + key loading.
4. **Identities table + `from_omniauth` rewrite — verified linking** (`.11`,
   NEW) — migration + `identities` model, identity-first lookup, cold-match
   blocks-with-guidance (no silent merge), `local→SSO` auto-link kept opt-in +
   `email_verified`-gated, denormalized-column sync, backfill migration, audit.
   The §6/§6a core. Depends on `.1`.
5. **Connected-Accounts UI** (`.12`, NEW) — signed-in Connect/unlink/view in
   the profile, last-method unlink guard, session invalidation on unlink, admin
   identity visibility. Depends on `.11` + `.8`.
6. **Per-provider logout** (`.9`) — `sessions_controller` resolves end_session
   by `session[:auth_method]`. Depends on `.8`.
7. **Rename rake task + backward-compat proof** (`.10`) — `rename_provider`
   updates `identities` + denormalized columns; explicit legacy-env spec; the
   identities backfill proof. Depends on `.11`.
8. **Live dual-provider round-trip** (`.5`) — Okta + login.gov sandbox on one
   dev login page; both full login/logout flows AND the signed-in Connect flow
   proven live. Depends on `.9`, `.2`, `.12`.

Then `.6` (dev+staging deploy config + Heroku audit) and `.3` (docs: login.gov
setup + Connected-Accounts how-to + provider table row flip) complete the epic.

## Out of Scope

- SAML; changes to LDAP/GitHub strategies (already coexist independently —
  though they DO get backfilled into `identities` and become linkable)
- Identity-proofing / step-up to IAL2 or FAL2+ as a Vulcan-enforced gate
  (login.gov assurance level is a per-deployment config, not built here)
- Production login.gov (requires IAA via DISA — PLAN-A milestone)
