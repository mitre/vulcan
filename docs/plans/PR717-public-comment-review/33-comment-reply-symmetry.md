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
- Decide: eager-include `responses` in the row payload (simple, fine
  if reply counts stay small — typical case <5) OR add a
  `GET /reviews/:id/responses` endpoint and lazy-load on expand.
  Recommend eager-include for v1; revisit if reply counts grow.

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

## Design questions to resolve before starting

- **Triage-table thread display:** inline expansion (recommended) vs
  thread-detail page. Inline preserves at-a-glance queue; thread page
  gives more space but takes you out of context.
- **Reply ordering:** chronological (oldest-first, like a chat) vs
  reverse-chronological (newest-first, like a forum). Currently
  RuleReviews uses chronological for nested replies under each
  parent. Stay consistent.
- **Triage of replies:** today only top-level comments have triage
  status. Replies inherit nothing. Keep that — replies are
  conversation, top-level is the unit of disposition. (But verify
  this matches your team's mental model.)

## Test plan

- Backend specs: `responses_count` populated correctly across all
  payloads; thread payloads round-trip through JSON archive
  export/import.
- Vue specs: `<CommentThread>` renders parent + replies, fires reply
  event with correct id, expand/collapse persists across navigations.
- Integration: post a reply from each of the five surfaces and
  confirm it appears in all three read-surfaces (triage table
  expanded, rule editor pullout, dedup banner).

## Out of scope

- Triage of replies (replies remain conversation, not adjudicable
  units)
- Threaded reply-to-replies UI (replies are flat under the parent;
  the data model allows deep nesting but the UX flattens it)
- Notification-on-reply (deferred with the rest of email/alerts to
  the v2 phase per `docs/plans/PR717-public-comment-review/README.md`
  §4 "Email out of scope")
