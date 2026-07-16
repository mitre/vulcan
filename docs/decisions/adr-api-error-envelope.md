# ADR: Canonical API Error Envelope — RFC 9457 Problem Details for Every JSON Error

- **Status:** DECIDED (Aaron, 2026-07-15) — all four open questions
  resolved by interview the same day the audit landed: machine code +
  human message (realized through the RFC 9457 vocabulary); adopt
  RFC 9457 `application/problem+json` now, in v2.x; the admins-to-ask
  block extends to token-authenticated API 403s (full parity); the
  disclosure policy is hybrid visibility-driven (discoverable → 403
  with contacts, non-discoverable → 404).
- **Date:** 2026-07-15
- **Deciders:** Aaron Lippold (all decisions, 2026-07-15 interview)
- **Companion:** `docs/development/seed-system.md` (API test users used
  for live-proving these bodies); `doc/openapi/CLAUDE.md` (contract
  rules the implementation must satisfy)

## 1. Context — four dialects for one question

An authenticated user browsing a raw API URL after their session was
superseded received a bare `{"error":"Unauthorized"}` and had no way to
know why or what to do. Fixing that one body (2026-07-15) exposed the
larger problem: the app answers "why can't I have this, and what do I
do?" in four different dialects.

| Path | JSON body today | Quality |
|---|---|---|
| 401 on `Api::` controllers | `{error, detail, how_to_authenticate}` | Rich (newest) |
| 401 everywhere else (warden throw) | Devise FailureApp default `{error: "You need to sign in or sign up before continuing."}` — even though warden knows the true cause (`session_limited` / `timeout` / `unauthenticated`) at that moment | Generic |
| 403 on legacy controllers | `permission_denied_payload` (`application_controller.rb`): machine code `error: 'permission_denied'` + human `message` + the project **admins to ask** + legacy `toast` | Richest |
| 403 on `Api::` controllers | `rescue_from NotAuthorizedError → {error: message}` — **shadows** the rich handler above | Poorest |

Supporting census (2026-07-15 audit):

- 26 `render json: { error: ... }` sites across 9 controller files.
- Two conflicting `error`-key conventions are both load-bearing:
  `useToast.js:79` switches on `error === "permission_denied"` (machine
  code) to render the admin-contact toast, while the 401 bodies and 11
  request/contract spec pins treat `error` as the human sentence.
- `app/javascript/api/baseApi.js` never displays 401 JSON: its
  `afterResponse` hook reloads the page on ajax 401 so the navigational
  Devise flow takes over. The rich 401 body's audience is therefore
  PAT/API consumers and humans on raw API URLs.
- OpenAPI shared responses disagree with reality: `Forbidden.yaml`
  documents a human-string `error` while legacy endpoints actually
  return the code + admins payload; there is no shared `NotFound.yaml`;
  10 path files declare 403 and 12 declare 404 with most blocks inline.
- The toast channel (`{toast: {title, message[], variant}}`) is a
  separate, locked contract for mutation feedback and is **not** part
  of this problem.

## 2. Decision 1 — machine code + human message

`error`-as-human loses: programs need a stable key, and the frontend
already banks on one for 403s. Every canonical error body carries a
stable machine identifier and separate human text. Copy can improve
without breaking a single client.

## 3. Decision 2 — adopt RFC 9457 Problem Details, now

The canonical envelope is RFC 9457 (`application/problem+json`), not an
in-house shape. Decision 1's "code" and "message" are realized through
the RFC's vocabulary:

- `type` — URI reference identifying the error class: the machine key.
  Vulcan uses absolute-path references that anchor into the live API
  docs, e.g. `/api/docs/errors#not_authenticated`.
- `title` — short human summary of the error class (stable per type).
- `status` — the HTTP status code, repeated in the body.
- `detail` — human explanation specific to this occurrence (the "why",
  including everything the server can distinguish).
- Extension members carry Vulcan's help blocks (§4): clients that don't
  recognize them ignore them, per the RFC.

Concrete bodies (the contract; copy may be tuned in review):

401, no credentials (`Api::BaseController`):

    {
      "type": "/api/docs/errors#not_authenticated",
      "title": "Not authenticated",
      "status": 401,
      "detail": "This request included no API token and no valid signed-in session. If you were signed in, the session may have timed out, been signed out, or ended because this account signed in from another location.",
      "how_to_authenticate": {
        "session": "Sign in through the web UI (/users/sign_in) and retry with the session cookie.",
        "token": "Create a personal access token (your profile page, or POST /personal_access_tokens) and send it in the request header: Authorization: Token <your-token>."
      }
    }

401, bad token (`ApiTokenAuthenticatable`): `type` `#invalid_token`,
`detail` naming revoked/expired/mistyped, same `how_to_authenticate`.

401, warden throw (custom failure app, JSON only): `type` per true
cause — `#session_superseded` ("this account signed in from another
location", stated definitively), `#session_timed_out`,
`#not_authenticated` — plus `how_to_authenticate`.

403 (one renderer for legacy and `Api::` alike): `type`
`#permission_denied`, `detail` = the guard's capability message,
extension `admins: [{name, email}]` when a project or component is in
scope (§4).

404: `type` `#not_found`, including concealment cases (§5).

400 family: `#parameter_missing`, `#page_out_of_range` etc., `detail`
from the existing exception messages.

Delivery notes:

- Responses set `Content-Type: application/problem+json`. OpenAPI
  response content keys move to that media type; `openapi_first`
  contract validation and Schemathesis `content_type_conformance` then
  enforce it mechanically.
- `baseApi.js` parses JSON bodies regardless of the problem media type
  and its 401-reload hook keys on status, so the SPA path is
  unaffected; `useToast.js` migrates its `permission_denied` string
  check to the `type` key.
- RFC 9457 clients must ignore unknown extension members, which is what
  makes `how_to_authenticate` and `admins` safe to carry.

## 4. Decision 3 — admins-to-ask extends to API consumers (full parity)

A PAT holder is the same trust boundary as a signed-in browser user, so
the 403 extension `admins` (project admin names and emails, already
served to every signed-in user by the legacy JSON endpoints) is served
on `Api::` 403s too. The thin `rescue_from NotAuthorizedError` in
`Api::BaseController` that shadows the rich handler is removed; one
renderer serves both worlds. The `toast` key survives inside the 403
body only as a legacy compatibility field until the frontend consumes
the problem fields directly — the toast *channel* for mutations is
untouched.

## 5. Decision 4 — hybrid, visibility-driven disclosure

Whether a caller may learn that a forbidden resource exists is decided
by the resource owner's existing `visibility` setting, not by a global
rule (the GitHub private-vs-internal model):

| Resource state | Denied response |
|---|---|
| Discoverable project (and its components) | 403 `#permission_denied` + `admins` — the request-access flow working as designed |
| Non-discoverable project (and its components), caller is not a member | 404 `#not_found` — existence concealed; body identical to a true miss |
| Non-discoverable project, caller is a member denied a higher action | 403 `#permission_denied` — a member already knows it exists, so an honest 403 |
| Instance-global resources (STIGs, SRGs) and released components | Not applicable — visible to all authenticated users |

Rationale: on a single-team instance, 403-with-contacts is the useful
answer; on a multi-organization instance, project existence plus who
runs it can reveal that a vendor has an unreleased effort in progress,
and RFC 9110 explicitly sanctions 404 for concealment. Making the
owner's visibility flag the policy serves both without an
instance-wide compromise, and keeps access requests possible exactly
where they are wanted. Enumeration note recorded deliberately: for
discoverable projects, authenticated members can learn existence and
admin contacts — that is the feature.

## 6. Consumer migration map (from the audit)

| Consumer | Change |
|---|---|
| `useToast.js:79` permission-denied branch | key on `type` (+ status) instead of `error === 'permission_denied'`; `admins` extension unchanged |
| `baseApi.js` 401 reload hook | none (status-based) |
| `Toaster.vue` admins rendering | none (shape of `admins` unchanged) |
| 11 request/contract pins on the 401 human string | re-pin to `type`/`title`/`detail` |
| 403/404/400 spec pins | re-pin to problem fields |
| `Unauthorized.yaml` / `Forbidden.yaml` / `ErrorResponse.yaml` / new `NotFound.yaml` | problem+json schemas + truthful examples (example validation is enforced at error severity) |
| Devise FailureApp | custom subclass, JSON/non-navigational only; HTML flows byte-identical |
| External API consumers | additive semantics; the `error` key is replaced by the problem fields — coordinated in release notes |

## 7. Consequences

- One renderer, one media type, one documented vocabulary; new error
  cases get a `type` anchor and docs entry instead of a bespoke body.
- The 403 guards gain a visibility consultation in the denial path
  (concealment), which is new behavior and needs both-visibility specs.
- Contract and media-type conformance make drift mechanical to catch.
- The v3 rewrite inherits a standards-compliant error surface instead
  of a house dialect.

## 8. Out of scope

- The toast mutation-feedback channel (locked contract).
- Sign-in page / HTML flash wording and session-limit behavior.
- 422 validation bodies (toast channel).
