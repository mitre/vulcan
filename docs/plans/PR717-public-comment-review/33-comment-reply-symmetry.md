# Task 33: Symmetric reply visibility + reply affordances

**Status:** drafted post-merge — Will surfaced this during browser
testing of PR-717's preview deploy. The asymmetry was confusing
enough that a Vulcan dev (Will) couldn't tell where his own posted
reply had landed.

**Principle:** wherever a comment is read, a Reply button must exist
on it; wherever replies exist, the surface must show them (or
indicate they exist and let the user reach them). Today only one
surface (rule editor's Comment History pullout) renders replies, and
only one surface (composer dedup banner) has a Reply affordance — and
they're different surfaces.

**Estimate:** ~6-7 hr Claude-pace (active session). Splittable into
three commits:
- (A) backend payload changes (~1 hr)
- (B) shared `<CommentThread>` component + integration into the
  simpler surfaces (~3 hr)
- (C) triage table + triage modal + My Comments thread expansion
  (~2-3 hr)

## Current asymmetry

| Surface | Shows top-level | Shows replies | Posts new comment | Posts reply |
|---|---|---|---|---|
| Triage table (`/components/:id/triage`) | yes | no | no (read-only feed) | no |
| Triage modal (`CommentTriageModal`) | parent only | no | no | no — gap |
| Rule editor Comment History pullout (`RuleReviews`) | yes | yes (nested) | no (separate composer) | no — gap |
| Composer dedup banner (`CommentDedupBanner`) | yes (rule+section match) | no | yes | yes ([Reply] link) |
| My Comments page (`UserComments`) | your own only | no | no | no |

`Review.top_level_comments` scope filters `responding_to_review_id IS
NULL`. Three of the five surfaces use it directly, hiding replies.

## Concrete changes

### Backend

- Add `responses_count` to every top-level comment row payload
  - `Component#paginated_comments` (`app/models/component.rb`)
  - `Project#paginated_comments` (`app/models/project.rb`)
  - `UsersController#comments_json_payload`
  - `CommentDedupBanner` payload source (the `/components/:id/comments`
    JSON used for prior-comment deduplication)
- **Lazy-load reply bodies** via a new `GET /reviews/:id/responses`
  endpoint. Authorization derives from the parent review's component
  via the existing `authorize_component_access` pattern — replies
  inherit the same visibility as their parent. Returns the reply
  chain serialized through `ReviewBlueprint` (same shape used for
  rendering top-level comments). Eager-including reply bodies in row
  payloads was rejected — the dedup banner endpoint downgrades to
  `authorize_logged_in` on released components, so eager-including
  there would expose every reply to any logged-in user.
- **Redact `commenter_display_name` PII fallback.** Today
  `ImportedAttribution#commenter_display_name` falls back to
  `commenter_imported_email` when both the resolved User and
  `commenter_imported_name` are nil. Spreading reply rendering across
  five surfaces makes this a PII-scraping vector via the dedup banner
  (broadly readable on released components). Change the fallback to
  `"(imported commenter)"` when only the email column is populated.
  Keep `commenter_imported_email` server-side only.
- **Defense-in-depth: forbid triage on replies.** Add a model
  validator: `triage_status` must be absent when
  `responding_to_review_id.present?`. Frontend already filters
  replies out of the triage queue; this prevents a future regression
  from silently letting replies become adjudicable.
- **Reply parent auth — keep the rule_id in the URL.**
  `ReviewsController#create` authorizes via `params[:rule_id]`. The
  `responding_to_must_be_same_rule` model validator is the backstop.
  Every reply-creation path must continue to POST to
  `/rules/:rule_id/reviews` — never derive the rule server-side from
  `responding_to_review_id`. This is a constraint on the new code,
  not a new endpoint.

### Shared Vue component

Build `<CommentThread>` — a row component that renders one top-level
comment + (optionally expanded) reply chain + a Reply button. Used
by every surface listed above so the read/reply UX stays consistent
across them. Props: `comment`, `replies`, `expanded`, `canReply`.
Emits: `expand`, `reply`, `triage`.

### Surface-specific integration

1. **Triage table** — replace flat `b-table` rows with stacked
   `<CommentThread>` cards (or nested rows). Default collapsed; click
   chevron to expand replies inline. Each row gets a Reply button
   that opens `CommentComposerModal` in reply mode.
2. **Triage modal** — render existing reply chain above the decision
   form. Add Reply button. Replies posted from here refresh the chain
   in place.
3. **Rule editor Comment History pullout** — add a Reply button on
   every comment row (parent + each existing reply). Currently no
   reply affordance here at all.
4. **My Comments** — same expand-thread pattern as triage table. Plus
   surface YOUR replies as their own rows when filtering by author —
   today My Comments hides replies, so your own replies vanish from
   your dashboard.
5. **Composer dedup banner** — show reply count next to each existing
   comment. Allow expanding to read the thread before deciding to
   compose new vs reply to existing.

## Design decisions (resolved)

- **Triage-table thread display:** inline expansion. Click chevron to
  expand the reply chain under the row; preserves the at-a-glance
  queue.
- **Reply ordering:** chronological (oldest-first), matching
  RuleReviews.
- **Triage of replies:** confirmed — replies are conversation, only
  top-level comments are adjudicable units. Enforced now at the
  frontend filter AND the model validator (see Backend §).
- **Reply payload strategy:** lazy-load via
  `GET /reviews/:id/responses` everywhere. Single auth gate per
  expansion, replies inherit parent's component visibility.
- **My Comments + discoverable projects:** replies match root
  comments. If you can see the parent on My Comments today (because
  it's yours, on a project you can access), expanding loads replies
  via the same auth gate as the parent. No reply-specific carve-out.

## Security review (incorporated 2026-05-04)

This plan was reviewed before any code commits. Findings folded into
Backend § above:
- C1: PII redaction for `commenter_display_name` fallback
- C2: lazy-load endpoint instead of eager-include (avoids broad reply
  exposure via the dedup banner)
- C3: reply parent auth must keep rule_id in the URL
- R1: replies inherit parent's auth (not gated separately)
- R2: model validator forbidding triage_status on replies
- CSRF/FormMixin wiring on every new reply-POST surface — verify in
  each surface integration commit
- Spec asserting closed-window reply rejection

## Test plan

- Backend specs:
  - `responses_count` populated correctly across all payloads
  - `GET /reviews/:id/responses` authorizes via parent's component
    (member, discoverable+released, denied for inaccessible components)
  - `commenter_display_name` redaction when only `commenter_imported_email`
    is populated (verify dedup banner payload, triage modal payload,
    My Comments payload)
  - Model validator: `Review` with `responding_to_review_id` cannot
    save with non-nil `triage_status`
  - Viewer cannot reply on a closed component (`reject_if_comments_closed`
    applies to `responding_to_review_id`-bearing reviews)
  - Thread payloads round-trip through JSON archive export/import
- Vue specs: `<CommentThread>` renders parent + replies, fires reply
  event with correct id, expand/collapse persists across navigations.
- Integration: post a reply from each of the five surfaces and
  confirm it appears in all three read-surfaces (triage table
  expanded, rule editor pullout, dedup banner).
- CSRF: each new reply-POST surface either includes `FormMixin` or
  imports `CommentComposerModal` (which mixes it in). Verify per
  surface commit.

## Out of scope

- Triage of replies (replies remain conversation, not adjudicable
  units)
- Threaded reply-to-replies UI (replies are flat under the parent;
  the data model allows deep nesting but the UX flattens it)
- Notification-on-reply (deferred with the rest of email/alerts to
  the v2 phase per `docs/plans/PR717-public-comment-review/README.md`
  §4 "Email out of scope")
