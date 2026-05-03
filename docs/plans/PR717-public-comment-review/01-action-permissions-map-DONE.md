# Task 01: ACTION_PERMISSIONS map (closes Copilot finding #1)

**Depends on:** —
**Unblocks:** 05, 07, 08, 09, 10
**Estimate:** 15 min Claude-pace
**File touches:**
- `app/models/review.rb` (add constants, replace `validate_project_permissions`)
- `spec/models/reviews_spec.rb` (add coverage)

**Closes:** Copilot finding #1 on PR #717 — viewer-can-`request_review` auth bypass.

---

## Step 1: Write the failing model spec

Append to `spec/models/reviews_spec.rb`, inside the existing `RSpec.describe Review` block:

```ruby
describe 'ACTION_PERMISSIONS map (per-action role gate)' do
  it 'rejects a viewer attempting request_review' do
    review = Review.new(action: 'request_review', comment: 'try', user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].join).to match(/insufficient permissions to request_review/i)
  end

  it 'rejects a viewer attempting revoke_review_request' do
    review = Review.new(action: 'revoke_review_request', comment: 'try', user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].join).to match(/insufficient permissions to revoke_review_request/i)
  end

  it 'rejects a viewer attempting request_changes' do
    review = Review.new(action: 'request_changes', comment: 'try', user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].join).to match(/insufficient permissions to request_changes/i)
  end

  it 'rejects an author attempting approve' do
    review = Review.new(action: 'approve', comment: 'lgtm', user: @p_author, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].join).to match(/insufficient permissions to approve/i)
  end

  it 'rejects an author attempting lock_control' do
    review = Review.new(action: 'lock_control', comment: 'lock', user: @p_author, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].join).to match(/insufficient permissions to lock_control/i)
  end

  it 'allows a viewer to comment' do
    review = Review.new(action: 'comment', comment: 'looks good', user: @p_viewer, rule: @p1r1)
    review.valid?
    expect(review.errors[:base].grep(/insufficient permissions/i)).to be_empty
  end

  it 'allows an admin to perform any action (smoke check)' do
    %w[comment request_review request_changes approve lock_control unlock_control].each do |action|
      review = Review.new(action: action, comment: 'x', user: @p_admin, rule: @p1r1)
      review.valid?
      perm_errors = review.errors[:base].grep(/insufficient permissions/i)
      expect(perm_errors).to be_empty,
                             "admin unexpectedly blocked from #{action}: #{perm_errors.inspect}"
    end
  end
end
```

This block uses `@p_viewer`, `@p_author`, `@p_admin`, `@p1r1` — these are already set up by the existing `before_all` in `reviews_spec.rb` (post-PR #717). If running locally before adding the block, confirm via `grep '@p_viewer\b' spec/models/reviews_spec.rb`.

## Step 2: Run the spec to verify it fails

```bash
bundle exec rspec spec/models/reviews_spec.rb -e "ACTION_PERMISSIONS map"
```

**Expected:** all 7 examples FAIL. The viewer→request_review case in particular fails because `validate_project_permissions` currently only checks `project_permissions.blank?`, not the role tier — exactly the bug Copilot flagged. No "insufficient permissions to ..." error is raised today.

If the spec passes immediately, STOP and surface — there's something we missed in the existing model.

## Step 3: Replace `Review::VALID_ACTIONS` with `ACTION_PERMISSIONS` + `TIER_ROLES`

In `app/models/review.rb`, locate the existing `VALID_ACTIONS` constant block (lines ~9-17, post-PR #717):

```ruby
VALID_ACTIONS = %w[
  comment
  request_review
  ...
].freeze
```

Replace it with:

```ruby
TIER_ROLES = {
  viewers:   %w[viewer author reviewer admin],
  authors:   %w[author reviewer admin],
  reviewers: %w[reviewer admin],
  admins:    %w[admin]
}.freeze

ACTION_PERMISSIONS = {
  'comment'               => :viewers,
  'request_review'        => :authors,
  'revoke_review_request' => :authors,
  'request_changes'       => :reviewers,
  'approve'               => :reviewers,
  'lock_control'          => :admins,
  'unlock_control'        => :admins
}.freeze

VALID_ACTIONS = ACTION_PERMISSIONS.keys.freeze  # back-compat alias; remove in a future cleanup PR
```

The `VALID_ACTIONS` alias keeps the inclusion validator from PR #717 working without changes:

```ruby
validates :action, inclusion: { in: VALID_ACTIONS, message: 'is not a recognized review action' }
```

## Step 4: Replace `validate_project_permissions` body

Locate `validate_project_permissions` (private method, around line 49-53):

```ruby
def validate_project_permissions
  return unless user && rule
  errors.add(:base, 'You have no permissions on this project') if project_permissions.blank?
end
```

Replace with:

```ruby
def validate_project_permissions
  return unless user && rule
  required_tier = ACTION_PERMISSIONS[action]
  return if required_tier.nil?  # inclusion validator catches unknown actions

  if project_permissions.blank?
    errors.add(:base, 'You have no permissions on this project')
    return
  end

  return if TIER_ROLES.fetch(required_tier).include?(project_permissions)

  errors.add(:base, "Insufficient permissions to #{action} on this component")
end
```

Notes:
- The "no permissions on this project" branch is preserved for users who have no membership at all
- `TIER_ROLES.fetch(...)` raises `KeyError` if a typo creeps in — safer than `[]` returning nil
- Error message is friendly English ("Insufficient permissions to comment...") not DISA-flavored — per design doc §3.1.1

## Step 5: Run the spec to verify it passes

```bash
bundle exec rspec spec/models/reviews_spec.rb -e "ACTION_PERMISSIONS map"
```

**Expected:** all 7 examples PASS.

## Step 6: Run the full reviews model spec to confirm no regressions

```bash
bundle exec rspec spec/models/reviews_spec.rb
```

**Expected:** all examples (existing + new) PASS. The existing `'allows any member, including viewers, to comment'` test from PR #717 should still pass — the new gate doesn't reject viewers from `comment` since ACTION_PERMISSIONS maps `comment` → `:viewers`.

If any existing test breaks, do NOT modify the test. Investigate the model.

## Step 7: Run impacted request specs

```bash
bundle exec rspec spec/requests/reviews_spec.rb spec/requests/rule_section_locks_spec.rb
```

**Expected:** all PASS. PR #717 already has request specs that will exercise this code path; they should all stay green.

## Step 8: Run RuboCop

```bash
bundle exec rubocop app/models/review.rb spec/models/reviews_spec.rb
```

**Expected:** 0 offenses. If autocorrect is needed, run `bundle exec rubocop --autocorrect app/models/review.rb spec/models/reviews_spec.rb` and re-run tests after.

## Step 9: Run vocabulary grep checks (per `98-vocabulary-grep-verification.md`)

```bash
# (a) DISA terms in user-facing templates? (Should be zero — we haven't added any yet anyway.)
# (b) Friendly UI labels in models/migrations? Should be zero.
grep -rnE "\"(accept|decline|closed)\"" app/models app/controllers db/migrate
```

**Expected:** 0 matches.

## Step 10: Commit

```bash
cat > /tmp/msg-01.md <<'EOF'
fix: per-action role gate via ACTION_PERMISSIONS map (closes Copilot #1)

Replaces the bare "no permissions on this project" check in
Review#validate_project_permissions with a tier-based role gate driven by
the new ACTION_PERMISSIONS constant. Each action declares its minimum role
tier (viewers / authors / reviewers / admins); the model enforces it
before any per-action state validator runs.

This closes the Copilot-flagged authorization regression in PR #717:
previously, with the controller filter relaxed to authorize_viewer_project,
a viewer sending action=request_review against an unlocked, not-under-review
rule would pass validation and become the review_requestor. The new gate
rejects with a friendly "Insufficient permissions to request_review" error.

VALID_ACTIONS is now derived from ACTION_PERMISSIONS.keys (single source of
truth — adding a new action means one map entry, not two).

Tests added for viewer→request_review, viewer→revoke_review_request,
viewer→request_changes, author→approve, author→lock_control. Existing
viewer→comment test continues to pass.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/models/review.rb spec/models/reviews_spec.rb
git commit -F /tmp/msg-01.md
rm /tmp/msg-01.md
```

## Step 11: Mark this task done

```bash
git mv docs/plans/PR717-public-comment-review/01-action-permissions-map.md \
       docs/plans/PR717-public-comment-review/01-action-permissions-map-DONE.md
git commit -m "chore: mark plan task 01 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- Copilot finding #1 is closed (will reply to the comment in post-implementation)
- `Review::ACTION_PERMISSIONS` and `TIER_ROLES` are available for downstream tasks (especially 05, 07, 08-12)
- `VALID_ACTIONS` is now derived; future tasks adding actions update one map only
- Existing test coverage is broader (5 new viewer/author rejection cases)
