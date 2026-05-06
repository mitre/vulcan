# Plan: Comment Reactions (👍 / 👎)

**Status:** Draft for review
**Date:** 2026-05-05
**Branch (proposed):** `feat/comment-reactions` off `master` after PR #717 merges

---

## Goal

Let any project member react to a comment with 👍 or 👎 — visible as a count near each comment in the rule thread + triage modal, with a hover tooltip showing reactor names. In the disposition-matrix CSV export, reactions are merged into the parent comment's existing `Thread Replies` cell as one-line entries (alongside text replies) so external triagers see them in raw text outputs.

## Decisions (from 2026-05-05 scoping + 2026-05-XX review-team feedback)

1. **Permissions:** viewer+ can react. (Same gate as posting comments.)
2. **Visibility:** Reactor **names only**, no email — same PII discipline as the existing comment author lists during a public review window.
3. **Phase gating:** Reaction toggles (POST) are allowed only when `Component#accepting_new_comments?` is true (i.e., `comment_phase == 'open'`). When the component is closed (regardless of `closed_reason` `'adjudicating'` or `'finalized'`), toggles return 422 with a friendly error. The GET reactors endpoint is intentionally **not** phase-gated — historical reactions stay visible during closed periods.
4. **UI placement:** Inline below each comment in `RuleReviews.vue` thread + below each comment in the triage modal's "Other comments on this rule" / canonical comment list. **Not** a column in the component-comments table (the table stays focused on triage state — reactions live in the per-comment views).
5. **Rate limiting:** Rack::Attack throttles — 60/min/user for POST, 300/min/user for GET (more generous because hover-fetch is per-comment). Both fall back to `req.ip` when unauthenticated so the throttle still meters anonymous traffic.
6. **CSV export:** Reactions are appended to the existing per-comment `Thread Replies` cell (alongside text replies), in `[name · timestamp] reacted thumbs-up` / `thumbs-down` format. Existing replies are already concatenated into one cell with `\n---\n` separators; reactions slot into the same stream. Conceptually: a reaction is just a one-character reply, so it lives where replies live. No new column, no new rows.
7. **Reactions on replies:** A user can react to any `action='comment'` Review, whether it's a top-level comment or a reply (a Review with `responding_to_review_id` set). Matches GitHub-comment-on-reply UX.
8. **Audit trail:** Reactions are audited via `vulcan_audited only: %i[kind], associated_with: :review`. Public-comment context may need a paper trail (a 👎 from a DISA reviewer is functionally a non-concur signal); toggle-off destroys the row, so without audits the kind history is gone. Start with full create+update+destroy auditing; if heavy public-comment periods make the audit table noisy, downgrade to event-only (just `create`) — the toggle-off and switch paths can drop audits without losing the initial signal.
9. **Vocabulary layering:** Following the PR #717 pattern, `kind` is stored DISA-neutral (`'up'`/`'down'`) on the wire and in the DB. UI labels (`'Thumbs up'`, `'Thumbs down'`), Bootstrap-Vue icon names (`hand-thumbs-up`, `hand-thumbs-down`), and CSV labels (`thumbs-up`, `thumbs-down`) all live in single-source-of-truth files: `config/locales/en.yml` (vulcan.reaction.*), `app/javascript/constants/reactionVocabulary.js`, and `Reaction::KIND_LABELS` (Ruby mirror). A parity spec asserts the three sources stay in sync.

## Architecture

### Storage

New `reactions` table:

```ruby
create_table :reactions do |t|
  t.references :review, null: false, foreign_key: { on_delete: :cascade }, index: true
  t.references :user,   null: false, foreign_key: { on_delete: :cascade }, index: true
  t.string :kind, null: false   # 'up' | 'down'
  t.timestamps
end
add_index :reactions, [:review_id, :user_id], unique: true   # one active reaction per user per comment
add_index :reactions, [:review_id, :kind]                     # fast count-by-kind
```

`on_delete: :cascade` on both FKs is required: `CommentTriageModal` already exposes a hard-delete admin path on Reviews. Without cascade, deleted-comment reactions orphan and the `(review_id, user_id)` unique index would block a returning user from re-reacting on a recreated comment with the same id (vanishingly unlikely but a real DB-integrity smell). User cascade matches the existing user-delete semantics.

Why a table instead of a JSONB column on Review (rejecting "Reaction-as-Review" too):
- Concurrent toggles are race-safe via the unique index; no read-modify-write loop in app code.
- `created_at` is free — gives us reactor-list ordering without extra plumbing.
- "Who reacted with X" is a normal query, not a JSON traversal.
- Cheap to add more `kind` values later if reactions extend beyond 👍/👎.
- Encoding reactions as `Review` rows with `action='reaction_up'` would force every Review validator, blueprint, paginated_comments scope, and triage query to special-case them. A separate table keeps Review semantics clean.

### Toggle behavior

One reaction per user per comment. The toggle endpoint is idempotent on the (user, review) pair:
- No existing row + click `up` → INSERT `up`.
- Existing `up` + click `up` → DELETE (toggle off).
- Existing `up` + click `down` → UPDATE kind to `down` (atomic switch).
- Existing `down` + click `down` → DELETE.
- Existing `down` + click `up` → UPDATE kind to `up`.

A user can never have both reactions active at once. The unique index on `(review_id, user_id)` enforces this in the DB.

### Wire shape

`ReviewBlueprint` (or wherever review payloads live for the rule thread + paginated_comments rows) gains a `reactions` field:

```json
{
  "id": 142,
  "comment": "Check text mentions runc 1.0…",
  "reactions": { "up": 3, "down": 1, "mine": "up" }
}
```

- `up`/`down`: aggregate counts.
- `mine`: current_user's reaction kind, or `null` if they haven't reacted.

`mine` is computed per-request from current_user; embedding it lets the frontend render the active state without a second round-trip. Counts come from a single GROUP BY (see Task 03).

The full reactor list is **not** embedded — it's lazy-fetched on hover via `GET /reviews/:id/reactions` so we don't ship every reactor's name with every page render.

### Endpoints

```
POST   /reviews/:id/reactions   { kind: 'up' | 'down' }   # toggle
GET    /reviews/:id/reactions                              # list reactors (lazy hover)
```

Both gated by `authorize_viewer_project` + the new `verify_comments_open` filter (POST only — GET works in any phase so closed-period viewers can still see who reacted to historical comments).

**Existence-oracle hardening:** `set_review` does NOT use `Review.find` directly (which raises 404 before authorization runs, leaking review-ID existence to non-members). Instead it does `Review.find_by(id: params[:review_id])` and, if nil OR if the review's project membership check fails, returns the same structured 403 (`permission_denied_payload`) for both. From the unauth user's perspective, "review doesn't exist" and "review exists but you can't see it" are indistinguishable.

Same pattern: `set_review` also asserts `@review.action == 'comment'` and treats non-comment reviews as non-existent (same 403). This blocks the model-validator path from being reachable via a non-comment Review URL.

POST returns the updated payload:
```json
{ "reactions": { "up": 4, "down": 1, "mine": "up" } }
```

GET returns:
```json
{
  "up":   [{ "name": "Alice Admin" }, { "name": "Bob Boss" }],
  "down": [{ "name": "Carol Crit" }]
}
```

Names only. Emails omitted per Decision 2.

### CSV export format

Existing disposition-matrix CSV (`app/lib/disposition_matrix_export.rb`) is one row per top-level comment. Replies to that comment are concatenated into the row's `Thread Replies` cell, separated by `\n---\n`, formatted as `[author · timestamp] body`. We slot reactions into that same cell.

Each reaction becomes one entry in the parent comment's `Thread Replies` cell:

```
[Sarah K · 2026-05-05T10:15:00Z] Could we soften the wording...
---
[Mike L · 2026-05-05T11:00:00Z] reacted thumbs-up
---
[John D · 2026-05-05T12:00:00Z] reacted thumbs-down
```

Order: chronological (interleaved with text replies by `created_at`). Author label uses the same defang/import-attribution path the existing reply formatter uses, so imported and live reactor names render consistently.

No new columns. No new rows. The `Thread Replies` header stays as-is; a column rename to "Thread Replies and Reactions" is unnecessary churn since the format is self-describing.

---

## Tasks

Each task is one TDD loop ending in one git commit. Run rubocop + relevant specs before each commit.

### Task 01: Reaction model + migration + cascade + audit

**Files:**
- `db/migrate/20260505XXXXXX_create_reactions.rb` (new)
- `app/models/reaction.rb` (new)
- `app/models/review.rb` (extend — add `has_many :reactions, dependent: :destroy`)
- `app/models/user.rb` (extend — add `has_many :reactions, dependent: :destroy`)
- `spec/models/reaction_spec.rb` (new)

**Steps:**
1. Migration: schema shown in Architecture > Storage. **Both FKs use `on_delete: :cascade`.**
2. Failing model specs covering:
   - `belongs_to :review`, `belongs_to :user`
   - `KINDS = %w[up down].freeze` constant
   - `validates :kind, inclusion: { in: KINDS }` rejects `'meh'`
   - `validates :user_id, uniqueness: { scope: :review_id }` rejects duplicate (user, review) pair
   - `must_be_comment_review` validator rejects reactions where `review.action != 'comment'`. Replies (action='comment' with `responding_to_review_id` set) ARE allowed per Decision 7 — add a positive spec asserting that case passes.
   - `vulcan_audited` writes an audit on create, on toggle (kind change), and on destroy (toggle-off). Three specs.
   - **Cascade specs:** destroying the parent Review nukes its reactions; destroying a User nukes their reactions. Use `Reaction.exists?(id:)` after the parent destroy.
3. Implement `app/models/reaction.rb`:
   ```ruby
   class Reaction < ApplicationRecord
     include VulcanAuditable

     belongs_to :review
     belongs_to :user

     vulcan_audited only: %i[kind], associated_with: :review

     KINDS = %w[up down].freeze

     validates :kind, inclusion: { in: KINDS }
     validates :user_id, uniqueness: { scope: :review_id, message: 'has already reacted to this comment' }
     validate :must_be_comment_review

     private

     def must_be_comment_review
       errors.add(:review, 'can only be reacted to on comment-action reviews') if review && review.action != 'comment'
     end
   end
   ```
4. Add `has_many :reactions, dependent: :destroy` to `Review` and `User`.
5. Run schema load, run spec, confirm green.
6. Commit: `feat: add Reaction model with up/down kinds, cascade, audit`.

### Task 02: Reaction vocabulary module (locale + JS + Ruby mirror)

**Files:**
- `config/locales/en.yml` (extend — add `vulcan.reaction.{labels,csv_labels,icons}` namespaces)
- `app/javascript/constants/reactionVocabulary.js` (new)
- `app/models/reaction.rb` (extend — add `Reaction::KIND_LABELS` and `Reaction::CSV_LABELS` constants)
- `spec/locales/reaction_keys_spec.rb` (new — parity spec mirroring `triage_keys_spec.rb`)

**Steps:**
1. Failing parity spec asserting symmetric key-set parity across the three sources, mirroring `spec/locales/triage_keys_spec.rb`. Three sources, three keys (up/down) on each, must agree.
2. Add to `config/locales/en.yml`:
   ```yaml
   vulcan:
     reaction:
       labels:
         up:   "Thumbs up"
         down: "Thumbs down"
       csv_labels:
         up:   "thumbs-up"
         down: "thumbs-down"
       icons:
         up:   "hand-thumbs-up"
         down: "hand-thumbs-down"
       closed_period_message:
         default:     "Reactions are closed for this component."
         adjudicating: "Reactions are closed — the disposition is being adjudicated."
         finalized:   "Reactions are closed — the disposition is finalized."
   ```

   The three `closed_period_message` variants mirror the
   `commentsClosedTooltip(closedReason)` helper in
   `app/javascript/constants/triageVocabulary.js` so the user sees the
   same wording for "comments closed" and "reactions closed". The
   controller (Task 04) selects the variant based on `component.closed_reason`.
3. Create `app/javascript/constants/reactionVocabulary.js`:
   ```js
   export const REACTION_KINDS = Object.freeze(["up", "down"]);
   export const REACTION_LABELS = Object.freeze({ up: "Thumbs up", down: "Thumbs down" });
   export const REACTION_ICONS  = Object.freeze({ up: "hand-thumbs-up", down: "hand-thumbs-down" });
   ```
4. Extend `app/models/reaction.rb`:
   ```ruby
   KIND_LABELS = { 'up' => 'Thumbs up', 'down' => 'Thumbs down' }.freeze
   CSV_LABELS  = { 'up' => 'thumbs-up', 'down' => 'thumbs-down' }.freeze
   ```
   These are the source of truth for backend rendering (CSV) and parity assertion. Frontend reads en.yml via I18n if needed; `reactionVocabulary.js` is the synchronous JS constant used in component templates.
5. Run parity spec, confirm green.
6. Commit: `feat: reaction vocabulary module — locale + JS + Ruby parity`.

### Task 03: Reaction.summary aggregate query helper

**Files:**
- `app/models/reaction.rb` (extend)
- `spec/models/reaction_spec.rb` (extend)

**Steps:**
1. Spec (failing): given an array of `review_ids`, `Reaction.summary(review_ids, current_user_id)` returns a hash `{ review_id => { up: N, down: M, mine: 'up' | 'down' | nil } }`.
2. Implement:
   ```ruby
   def self.summary(review_ids, current_user_id = nil)
     return {} if review_ids.blank?

     counts = where(review_id: review_ids).group(:review_id, :kind).count
     mine = if current_user_id
              where(review_id: review_ids, user_id: current_user_id)
                .pluck(:review_id, :kind).to_h
            else
              {}
            end

     review_ids.each_with_object({}) do |rid, h|
       h[rid] = {
         up:   counts[[rid, 'up']]   || 0,
         down: counts[[rid, 'down']] || 0,
         mine: mine[rid]
       }
     end
   end
   ```
3. Spec covers: zero-reaction case, mixed up/down, current_user_id present and absent (nil → no mine plumbing, just counts), `mine` returns nil for users who haven't reacted.
4. Commit: `feat: add Reaction.summary aggregate query`.

### Task 04: ReactionsController + routes

**Files:**
- `config/routes.rb`
- `app/controllers/reactions_controller.rb` (new)
- `spec/requests/reactions_spec.rb` (new)

**Steps:**
1. Routes:
   ```ruby
   resources :reviews, only: [] do
     resources :reactions, only: [:index, :create]
   end
   ```
   The `create` action handles toggle (per Decision spec). `index` lists reactors.
2. Failing request specs:
   - **POST authentication:** unauthenticated → redirect / 401.
   - **POST authorization:** non-member → structured 403 with admin contacts.
   - **POST happy path (viewer):** post `kind=up` on a comment in an `open` component → 200, body has `reactions: { up: 1, mine: 'up' }`. DB has one reaction row.
   - **POST toggle off:** same user posts `kind=up` again → 200, body has `reactions: { up: 0, mine: nil }`. DB has zero rows for that (user, review).
   - **POST switch:** user with existing `up` posts `kind=down` → 200, body has `reactions: { up: 0, down: 1, mine: 'down' }`. DB has one row, kind='down'.
   - **POST invalid kind:** post `kind=meh` → 422 with `Kind is not included in the list`.
   - **POST on reply (responding_to_review_id present):** succeeds (Decision 7 — replies are reactable).
   - **POST on non-comment review:** try to react to an `action=approve` review → returns the structured 403 (existence-oracle hardening, NOT 422 from the model — `set_review` rejects before the controller body runs).
   - **POST on nonexistent review id:** returns the structured 403 (same shape as authz denial — does NOT 404, see Endpoints section).
   - **POST on closed component:** create the review against a component with `comment_phase='closed'` → 422 with friendly message ("Reactions are closed for this component."). The phase gate filter rejects before model logic runs. (Task 06 hardens the gate further.)
   - **POST concurrent toggle (TOCTOU spec):** simulate two simultaneous POSTs from the same user. Assert both responses are 2xx, exactly one reaction row exists at the end, and no 500 leaks via unhandled `RecordNotUnique`. **Heads up on the test infra:** RSpec's transactional fixtures + AR connection-pool semantics make multi-threaded tests flaky. Each thread needs its own connection (`ActiveRecord::Base.connection_pool.with_connection { ... }`) and the parent test transaction won't see the spawned threads' writes. If this proves too brittle, fall back to invoking `toggle_reaction` directly with `Concurrent::Promises.zip(future1, future2).value!` and a `before { ActiveRecord::Base.connection_pool.checkin_timeout = 5 }` setup, OR drop the multi-threaded path and add a unit-level test on `toggle_reaction` that mocks `find_by` to return a stale row, then asserts the rescue path.
   - **POST as outsider (no project membership):** structured 403 with admin contacts.
   - **GET happy path:** with 3 up + 1 down reactors → 200, body `up: [{name: ...}, {name: ...}, {name: ...}], down: [{name: ...}]`. Reactor objects contain `name` ONLY — assert `keys == ['name']` (no `email`, no `id`).
   - **GET on closed component:** still works (Decision 3 — historical reactions remain visible).
   - **GET on nonexistent review id:** structured 403 (oracle hardening).
3. Implement controller. Sketch:
   ```ruby
   class ReactionsController < ApplicationController
     before_action :set_review
     before_action :authorize_viewer_project
     before_action :verify_comments_open, only: :create

     def index
       summary = Reaction.where(review_id: @review.id)
                         .includes(:user)
                         .order(:created_at)
                         .group_by(&:kind)
       render json: {
         up:   (summary['up']   || []).map { |r| { name: r.user.name } },
         down: (summary['down'] || []).map { |r| { name: r.user.name } }
       }
     end

     def create
       kind = params.require(:kind)
       unless Reaction::KINDS.include?(kind)
         return render json: error_toast("Invalid reaction kind."), status: :unprocessable_entity
       end

       toggle_reaction(kind)

       summary = Reaction.summary([@review.id], current_user.id)[@review.id]
       render json: { reactions: summary }
     rescue ActiveRecord::RecordInvalid => e
       render json: error_toast(e.record.errors.full_messages), status: :unprocessable_entity
     end

     private

     # TOCTOU-safe toggle: lock the (review_id, user_id) row inside the
     # transaction, OR rescue RecordNotUnique when the lookup-then-create
     # races. Two concurrent POSTs from one user → exactly one survives.
     def toggle_reaction(kind)
       Reaction.transaction do
         existing = Reaction.lock.find_by(review_id: @review.id, user_id: current_user.id)
         if existing.nil?
           Reaction.create!(review: @review, user: current_user, kind: kind)
         elsif existing.kind == kind
           existing.destroy!
         else
           existing.update!(kind: kind)
         end
       end
     rescue ActiveRecord::RecordNotUnique
       # Lost a TOCTOU race — the other transaction won. Just re-read and
       # report current state. The summary call after this picks up the
       # winning row.
       nil
     end

     # Returns 403 with admin contacts for both "not found" and
     # "not a comment" — same response shape as authz denial. Closes the
     # existence-oracle path.
     def set_review
       @review = Review.find_by(id: params[:review_id])
       deny! unless @review && @review.action == 'comment'
       @project = @review&.rule&.component&.project
     end

     # Soft-existence message: same 403 status whether the review is
     # missing or unreachable, but the toast says "isn't available"
     # rather than "permission denied" — closes the existence oracle
     # without confusing a user who hit a stale link to a deleted comment.
     def deny!
       payload = { error: 'permission_denied',
                   message: "The requested comment isn't available.",
                   admins: [],
                   toast: { title: 'Not available.',
                            message: "The requested comment isn't available.",
                            variant: 'danger' } }
       render json: payload, status: :forbidden
     end

     def verify_comments_open
       component = @review.rule.component
       return if component.accepting_new_comments?

       message = I18n.t("vulcan.reaction.closed_period_message.#{component.closed_reason || 'default'}",
                        default: I18n.t('vulcan.reaction.closed_period_message.default'))
       render json: error_toast(message), status: :unprocessable_entity
     end

     def error_toast(message)
       { toast: { title: "Could not save reaction.", message: Array(message), variant: "danger" } }
     end
   end
   ```
4. Run all reactions specs, confirm green.
5. Commit: `feat: add ReactionsController with toggle + index endpoints`.

### Task 05: Embed reactions summary in review payloads

**Files:**
- `app/controllers/components_controller.rb` (extend — triage table; inject `mine` into rows after model returns)
- `app/controllers/users_controller.rb#comments_json_payload` (extend — My Comments page rows)
- `app/controllers/reviews_controller.rb#responses` (extend — reply chain rows from the Task 33A endpoint)
- `app/models/component.rb#paginated_comments` (extend rows builder — add `up`/`down` counts only)
- `app/models/project.rb#paginated_comments` (mirror)
- `app/blueprints/review_blueprint.rb` (extend — source for the rule-thread review serialization that `RuleReviews.vue` and `CommentTriageModal` consume)
- specs

**Steps:**
1. **Per Web Dev review #5: keep the model pure.** The model returns `up` and `down` counts only; `mine` is computed in the controller after the model returns rows. This avoids threading `current_user_id` through `paginated_comments` and its callers.
2. Identify every payload site that emits review rows the frontend reads:
   - **Rule thread** — `RuleBlueprint`'s `:editor` view associates `:reviews` via `ReviewBlueprint`. Consumed by `RuleReviews.vue` + `CommentTriageModal`.
   - **Triage table** — `Component#paginated_comments` (component-scope) + `Project#paginated_comments` (project-aggregate). Consumed by `ComponentComments.vue`.
   - **Dedup banner** — `components_controller#comments` reuses `paginated_comments`, so it inherits the change automatically.
   - **My Comments page** — `users_controller#comments_json_payload` builds rows by hand. Needs the same per-row `up`/`down`/`mine` injection (without `mine`, the My Comments page can't show the user's own reaction state).
   - **Reply chain endpoint** — `reviews_controller#responses` emits hand-built reply rows (see Task 33A). Replies are reactable (Decision 7); these rows need reactions too.
3. Failing specs covering each site:
   - `spec/blueprints/review_blueprint_spec.rb` — top-level + reply rows from `ReviewBlueprint` carry `reactions: { up: N, down: M }` (no `mine`).
   - `spec/models/components_spec.rb#paginated_comments` + `spec/models/projects_spec.rb#paginated_comments` — same.
   - `spec/requests/users_spec.rb` — My Comments JSON rows have `reactions: { up:, down:, mine: }` (mine injected by the controller).
   - `spec/requests/reviews_spec.rb` — `GET /reviews/:id/responses` rows have `reactions: { up:, down:, mine: }`.
   - Each controller test: counts come from the model; `mine` lookup is a single batched `Reaction.where(review_id: ids, user_id: current_user.id).pluck(:review_id, :kind).to_h`.
4. **Watch N+1.** Per controller call: one GROUP BY for counts (already in the model row build), one indexed pluck for `mine`. Two queries total per page render regardless of row count. Reply-chain endpoint adds a third for its own ID set since reply IDs aren't in the parent payload.
5. Run impacted specs, confirm green.
6. Commit: `feat: embed reactions summary in review payloads`.

### Task 06: Phase gating regression spec

**Files:**
- `spec/requests/reactions_spec.rb` (extend if not already in Task 04)

**Steps:**
This task exists as a sanity check; the gate itself goes in Task 04's controller. Add focused regression specs for each phase combination:
- `comment_phase='open'` → reaction POST succeeds.
- `comment_phase='closed' closed_reason='adjudicating'` → 422.
- `comment_phase='closed' closed_reason='finalized'` → 422.
- GET works in all three (historical visibility).

Skip if Task 04's specs already cover this comprehensively. (They probably do — this task may collapse into Task 04 at execution time.)

### Task 07: Rate limit reactions endpoints

**Files:**
- `config/initializers/rack_attack.rb` (extend)
- `spec/requests/rack_attack_spec.rb` (extend)

**Steps:**
1. Failing specs:
   - 60 successful POST `/reviews/:id/reactions` calls in a minute work; the 61st returns 429.
   - 300 successful GET `/reviews/:id/reactions` calls in a minute work; the 301st returns 429.
   - Throttle key falls back to `req.ip` when unauthenticated (not `nil`, which would silently bypass the throttle entirely).
2. Add two throttles:
   ```ruby
   throttle('reactions_post/user', limit: 60, period: 60.seconds) do |req|
     if req.path.match?(%r{\A/reviews/\d+/reactions\z}) && req.post?
       req.env['warden']&.user&.id&.to_s || req.ip
     end
   end

   throttle('reactions_get/user', limit: 300, period: 60.seconds) do |req|
     if req.path.match?(%r{\A/reviews/\d+/reactions\z}) && req.get?
       req.env['warden']&.user&.id&.to_s || req.ip
     end
   end
   ```
3. Confirm green.
4. Commit: `feat: rate-limit reaction POST (60/min) and GET (300/min)`.

### Task 08: Frontend ReactionButtons component

**Files:**
- `app/javascript/components/shared/ReactionButtons.vue` (new)
- `spec/javascript/components/shared/ReactionButtons.spec.js` (new)

**Steps:**
1. Failing Vitest spec describing the props/events/behavior:
   - Props: `reviewId: Number`, `reactions: { up:, down:, mine: }`, `disabled: Boolean` (true when component closed).
   - Renders two reaction buttons (👍/👎) with counts, plus a "show reactors" trigger when count > 0.
   - Active state styling when `mine === 'up'` or `'down'`.
   - Click emits `toggle` with `kind: 'up' | 'down'` — parent owns the axios call so the component is testable in isolation.
   - **`b-popover` (not `b-tooltip`) on the reactors trigger.** Triggers: `hover focus click`. The trigger element is a focusable `b-button variant="link" size="sm"` with `aria-label="Show reactor names"` so keyboard, mouse, and touch all work.
   - Popover `show` event fires the axios GET, which renders into the popover slot. Loading state is a `<b-spinner small />`. Result is cached on the component instance for the page lifetime to avoid re-fetching on repeated hovers.
   - When `disabled=true`, the toggle buttons render disabled with the closed-period message from `vulcan.reaction.closed_period_message` (I18n).
   - **Mobile/WCAG 2.5.5 AA:** drop `size="sm"` (or override scoped CSS `min-height: 44px; min-width: 44px;`) so the tap target meets the 44×44 CSS-px AA minimum.
2. Sketch:
   ```vue
   <template>
     <span class="reaction-buttons">
       <b-button
         :variant="reactions.mine === 'up' ? 'primary' : 'outline-secondary'"
         class="reaction-btn"
         :disabled="disabled"
         :title="disabled ? closedMessage : ''"
         @click="$emit('toggle', 'up')"
       >
         <b-icon :icon="REACTION_ICONS.up" /> {{ reactions.up }}
       </b-button>
       <b-button
         :variant="reactions.mine === 'down' ? 'primary' : 'outline-secondary'"
         class="reaction-btn"
         :disabled="disabled"
         :title="disabled ? closedMessage : ''"
         @click="$emit('toggle', 'down')"
       >
         <b-icon :icon="REACTION_ICONS.down" /> {{ reactions.down }}
       </b-button>

       <b-button
         v-if="reactions.up + reactions.down > 0"
         :id="popoverId"
         variant="link"
         size="sm"
         class="reactors-trigger"
         aria-label="Show reactor names"
       >
         <b-icon icon="people" />
       </b-button>
       <b-popover
         v-if="reactions.up + reactions.down > 0"
         :target="popoverId"
         triggers="hover focus click"
         placement="top"
         @show="onPopoverShow"
       >
         <div v-if="loading"><b-spinner small /></div>
         <div v-else>
           <div v-if="reactors.up.length"><strong>👍</strong> {{ reactors.up.map(r => r.name).join(', ') }}</div>
           <div v-if="reactors.down.length"><strong>👎</strong> {{ reactors.down.map(r => r.name).join(', ') }}</div>
         </div>
       </b-popover>
     </span>
   </template>

   <script>
   import axios from "axios";
   import { REACTION_ICONS } from "../../constants/reactionVocabulary";

   export default {
     name: "ReactionButtons",
     props: {
       reviewId: { type: Number, required: true },
       reactions: { type: Object, required: true },
       disabled: { type: Boolean, default: false },
     },
     data() {
       return {
         REACTION_ICONS,
         loading: false,
         loaded: false,
         reactors: { up: [], down: [] },
         closedMessage: this.$t ? this.$t('vulcan.reaction.closed_period_message')
                                : 'Reactions are closed for this component.',
       };
     },
     computed: {
       popoverId() { return `reactors-popover-${this.reviewId}`; },
     },
     methods: {
       async onPopoverShow() {
         if (this.loaded) return;            // page-lifetime cache
         this.loading = true;
         try {
           const { data } = await axios.get(`/reviews/${this.reviewId}/reactions`);
           this.reactors = data;
           this.loaded = true;
         } finally {
           this.loading = false;
         }
       },
     },
   };
   </script>

   <style scoped>
   .reaction-btn { min-height: 44px; min-width: 44px; }   /* WCAG 2.5.5 AA */
   .reactors-trigger { padding: 0 0.25rem; }
   </style>
   ```
3. Confirm green.
4. Commit: `feat: ReactionButtons Vue component with accessible popover`.

### Task 09: Wire ReactionButtons into RuleReviews + CommentTriageModal

**Files:**
- `app/javascript/components/rules/RuleReviews.vue`
- `app/javascript/components/components/CommentTriageModal.vue`
- existing specs

**Steps:**
1. In `RuleReviews.vue`: render `<ReactionButtons>` under each comment in the thread (top-level + replies — Decision 7 allows reactions on replies). Pass `:reactions="comment.reactions"`, `:disabled="!commentsOpen"`, `:review-id="comment.id"`. Listen for `@toggle` and call axios.
2. In `CommentTriageModal.vue`: same pattern for the canonical comment + the "other comments on this rule" list.
3. Plumb `commentsOpen` from the parent (`component.comment_phase === 'open'`).
4. **Optimistic-update + revert-on-error pattern (explicit).** Snapshot the prior `reactions` object before the optimistic update so we have somewhere to revert to:
   ```js
   async function onToggle(comment, kind) {
     const prev = { ...comment.reactions };
     // optimistic: increment/decrement based on prior state
     this.$set(comment, 'reactions', this.optimisticUpdate(prev, kind));
     try {
       const { data } = await axios.post(`/reviews/${comment.id}/reactions`, { kind });
       this.$set(comment, 'reactions', data.reactions);   // server-authoritative replace
     } catch (err) {
       this.$set(comment, 'reactions', prev);             // revert
       this.alertOrNotifyResponse(err);
     }
   }
   ```
   `optimisticUpdate(prev, kind)` mirrors the server toggle logic (no existing → +1; existing same kind → -1; existing other kind → -1 other / +1 new).
5. **Revert-on-error spec:** mock axios.post to reject with a 422; assert local state matches the pre-click snapshot AND the toast was rendered.
6. Update existing component specs if any assertions on the rendered thread structure.
7. Lint + vitest.
8. Commit: `feat: wire reactions into rule thread and triage modal`.

### Task 10: CSV export — append reactions to Thread Replies cell

**Files:**
- `app/lib/disposition_matrix_export.rb`
- `spec/lib/disposition_matrix_export_spec.rb`

**Steps:**
1. Failing spec: given a comment with 1 text reply and 2 reactions across timestamps, the `Thread Replies` cell on the comment's row contains all 3 entries joined by `\n---\n`, in chronological (`created_at` ascending) order. Reactions render as `[name · iso8601_timestamp] reacted thumbs-up` (or `thumbs-down`). The CSV label literal comes from `Reaction::CSV_LABELS` (Task 02), not from a string-interpolated `kind` — keeps the wire/UI/CSV vocabularies aligned through one source of truth.
2. **Spec for reactions on replies (Decision 7):** create a top-level comment with one reply, then react to that reply (not the parent). The reaction MUST appear in the parent comment's `Thread Replies` cell, interleaved chronologically alongside the reply text. This is the gap the original plan missed: reactions on replies need to flow into the same per-top-level cell, not vanish.
3. **Spec for tie-stable ordering:** create a reply and a reaction with identical `created_at` (microsecond-equal); assert the rendered cell uses a deterministic order (`type` then `id` after `created_at`) so cross-export diffs don't churn.
4. **Spec for nil-user defensive fallback:** create a reaction with no associated User (only reachable if the FK is breached, but defensive) — `reaction_author_label` should return `'(unknown)'`, not raise NoMethodError.
5. Identify the existing reply-cell builder (`build_row` + `format_reply` in `app/lib/disposition_matrix_export.rb`). Extend it to also accept the comment's reactions (including reactions on its replies); format each reaction with a new `format_reaction` helper; merge-and-sort the combined entry list before joining.
6. Add a `format_reaction` private helper:
   ```ruby
   def self.format_reaction(reaction)
     label = Reaction::CSV_LABELS.fetch(reaction.kind)   # one source of truth
     "[#{defang(reaction_author_label(reaction))} · #{reaction.created_at.iso8601}] reacted #{label}"
   end

   def self.reaction_author_label(reaction)
     # `belongs_to :user` is non-optional (Task 01), so reaction.user
     # should always be present in normal flows. Defensive fallback for
     # FK-breach edge case (e.g., manually deleted user row bypassing
     # cascade somehow).
     reaction.user&.name || '(unknown)'
   end
   ```
   No imported-attribution branch — Task 01's schema doesn't add `commenter_imported_*` columns to `reactions`, and reactions are only creatable via the live UI in v1. If archive-import grows reaction support later, that task adds the columns + this fallback together.
7. **Reactions-on-replies preload.** The existing reply preload (`load_replies(top_level_ids)`) groups replies by parent ID. The reaction preload must cover BOTH top-level review IDs AND their reply IDs so reactions posted on a reply still surface in the parent's cell. Sketch:
   ```ruby
   def self.load_reactions(top_level_reviews, replies_by_parent)
     review_ids = top_level_reviews.map(&:id) +
                  replies_by_parent.values.flatten.map(&:id)
     return {} if review_ids.empty?
     Reaction.where(review_id: review_ids).includes(:user).group_by(&:review_id)
   end
   ```
   Then in `build_row`, when building the entry list for the parent comment, walk both the parent's reactions AND every reply's reactions:
   ```ruby
   reply_list = replies_by_parent[review.id] || []
   reactions_for_parent = reactions_by_review[review.id] || []
   reactions_for_replies = reply_list.flat_map { |r| reactions_by_review[r.id] || [] }

   entries = (
     reply_list.map { |r| { sort_key: [r.created_at, 'reply', r.id], formatted: format_reply(r) } } +
     (reactions_for_parent + reactions_for_replies).map { |x| { sort_key: [x.created_at, 'reaction', x.id], formatted: format_reaction(x) } }
   ).filter { |e| e[:formatted].present? }
    .sort_by { |e| e[:sort_key] }

   thread_cell = entries.map { |e| e[:formatted] }.join("\n---\n")
   ```
   The `[created_at, type, id]` triple is total-order-deterministic regardless of Ruby's `sort_by` stability spec. Two preloads (replies + reactions), no per-row queries.
8. Update existing CSV specs only if they asserted exact `Thread Replies` cell length with no reactions present — should be unaffected because the reactions table is empty in those fixtures. Add new specs covering: happy mixed case (top-level reaction + reply text), reactions-on-replies, tie-stable ordering, nil-user fallback.
9. Lint, run impacted specs.
10. Commit: `feat: append reactions (parent + reply targets) to disposition-matrix Thread Replies cell`.

### Task 11: Documentation + CHANGELOG

**Files:**
- `CHANGELOG.md` (`### Added` section)
- `docs/development/authorization.md` (extend the Rules permissions table — reactions row)
- `docs/user-guide/` if a user-facing doc page covers comments

**Steps:**
1. `CHANGELOG.md` (Unreleased):
   - Added: comment reactions (👍/👎) on rule comments. Reactions are visible as counts on each comment in the rule thread + triage modal; click the people-icon to see reactor names (works on hover, focus, and tap — accessible to keyboard and touch users). Reactions are merged into the parent comment's `Thread Replies` cell in the disposition-matrix CSV export (alongside text replies, in chronological order) as `[name · timestamp] reacted thumbs-up` entries. Audited via the `vulcan_audited` gem so the toggle history is preserved.
   - Added: rate limits on reaction endpoints (60/min/user POST, 300/min/user GET) via Rack::Attack.
2. authorization.md table: add row "React to a comment" → Component viewer+, only when `comment_phase='open'`. (GET reactor list works in any phase for historical visibility.)
3. Commit: `docs: changelog + authorization docs for comment reactions`.

### Task 99: Final sweep

**Steps:**
- `bundle exec parallel_rspec spec/` → 0 failures
- `pnpm vitest run` → 0 failures
- `bundle exec rubocop` → 0 offenses
- `yarn lint` → 0 warnings
- `bundle exec brakeman` → no new warnings
- Manual smoke:
  - As project author: open a comment in the rule thread → click 👍 → count goes 0→1, button highlights → click again → count back to 0.
  - As a different viewer: 👎 the same comment → count shows 1 down + 0 up.
  - Hover OR tab-focus OR tap the people-icon → popover shows reactor names (verify on desktop browser + mobile/touch device or browser-mobile-emulation).
  - Flip component to `comment_phase='closed'` → buttons render disabled with closed-period tooltip; manually crafted POST returns 422 with friendly error toast. The optimistic UI properly reverts and shows the toast.
  - Hard-delete a comment with reactions (via the admin path) → DB rows for those reactions are gone (cascade verified).
  - Export disposition-matrix CSV → confirm the parent comment's `Thread Replies` cell contains `[name · timestamp] reacted thumbs-up` / `thumbs-down` entries interleaved chronologically with any text replies, separated by `\n---\n`.
  - 61st POST in a minute → 429. 301st GET in a minute → 429.
  - Concurrent toggle (rapid double-click): no 500 leak; UI ends up in consistent state.
- Push, get a review.

---

## Out of scope (defer)

- More than 👍/👎 (GitHub's 6-reaction set, custom emoji): trivial extension of `Reaction::KINDS`, but UX work to design the picker. v2.
- Reactions in My Comments page (showing "5 people 👍'd your comment!"): a notification/digest feature; the v1 user feedback loop is the rule thread itself.
- Real-time updates (live count animation when someone else reacts): no ActionCable in Vulcan today; deferred.
- Reaction-based triage signal ("sort by net upvotes" in component-comments table): mentioned in the original scoping; deferred until we see whether triagers actually want this.
- Reactions on non-comment Reviews (approve, lock_control, etc.): explicitly disallowed by the model validator — only comment-action reviews are reactable.
- Sortable/filterable reactor lists in the hover tooltip: v1 just lists names in `created_at` order.

## Risks

- **Cell length on hot comments in CSV.** A comment with 50 👍 produces a 50-line `Thread Replies` cell (vs. 50 extra rows in the original Type-column proposal — which the user-confirmed cell-merge format avoids entirely). Most CSV viewers (Excel via Power Query, `awk`, `csvkit`) handle multi-line cells fine. Worst case: a future flag could collapse to a count-only summary.
- **Phase gating UX race.** Closing a component while a viewer's reaction click is in-flight: POST 422s, optimistic UI reverts (Task 09 spec), toast tells them "Reactions are closed for this component."
- **GET reactors performance.** Hover-scrolling a 50-comment thread = up to 50 GETs even with the per-component cache. Mitigations in place: (a) page-lifetime cache per `ReactionButtons` instance (Task 08), (b) GET-specific 300/min/user rate limit (Task 07). If usage shows the cache miss rate is high, embedding the full reactor list in the row payload is the next step (simple if typical counts stay <10/comment, which they should given the 60/min POST throttle).
- **Audit volume.** Reactions are toggled relatively often (cheap action), and `vulcan_audited only: %i[kind]` writes an audit row per create/update/destroy. A heavy public-comment period could 5x or 10x the audit table growth. Acceptable trade-off for the paper trail; if it gets painful, can switch to event-only auditing (just create) or a separate `reaction_history` table.
- **Mobile target sizing trade-off.** Bumping buttons to 44px from `size="sm"`'s ~28px makes the reaction toolbar visually heavier on desktop. Scoped CSS keeps the change isolated to `ReactionButtons`; the alternative — leaving sm and accepting a WCAG 2.5.5 violation — is not a real option.

## Effort estimate

~4–6 hours of focused execution, following the same TDD-per-commit cadence as PR #717. Backend tasks (01-07) are mechanical; frontend (08-09) is the bulk of the work; CSV (10) is a self-contained tweak.

Tasks are mostly sequential within each layer. Parallel-friendly pairs (no shared files): 03 + 07 (model summary + rate limit), 08 + 10 (frontend popover + CSV). For a single agent: just go in numeric order.
