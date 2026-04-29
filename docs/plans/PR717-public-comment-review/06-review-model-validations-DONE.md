# Task 06: Review model validations + audited gem + transaction discipline

**Depends on:** 01, 04
**Unblocks:** 08, 09, 10, 11, 12
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/models/review.rb` (constants, validators, scopes, audited config)
- `spec/models/reviews_spec.rb`

This task wires up all the model-layer guard-rails for the lifecycle columns added in Task 04 — invariants, auto-set rules, audit trail, and the strict TRIAGE_STATUSES enum.

---

## Step 1: Write the failing model specs

Append to `spec/models/reviews_spec.rb`:

```ruby
describe 'triage_status enum' do
  it 'rejects an unknown triage_status' do
    review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                        triage_status: 'whatever')
    review.valid?
    expect(review.errors[:triage_status].join).to match(/included in the list/i)
  end

  it 'accepts every value in TRIAGE_STATUSES' do
    Review::TRIAGE_STATUSES.each do |status|
      review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                          triage_status: status)
      review.valid?
      expect(review.errors[:triage_status]).to be_empty,
                                                "rejected: #{status}"
    end
  end
end

describe 'section enum' do
  it 'rejects an unknown section' do
    review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                        section: 'whatever')
    review.valid?
    expect(review.errors[:section].join).to match(/recognized section/i)
  end

  it 'accepts NULL (general comment)' do
    review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                        section: nil)
    review.valid?
    expect(review.errors[:section]).to be_empty
  end

  it 'accepts every key in SECTION_KEYS' do
    Review::SECTION_KEYS.each do |key|
      review = Review.new(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1,
                          section: key)
      review.valid?
      expect(review.errors[:section]).to be_empty, "rejected: #{key}"
    end
  end
end

describe 'duplicate_of_review_id invariants' do
  let!(:original) {
    Review.create!(action: 'comment', comment: 'original', user: @p_viewer, rule: @p1r1)
  }

  it 'requires a target when triage_status is duplicate' do
    review = Review.new(action: 'comment', comment: 'dup', user: @p_viewer, rule: @p1r1,
                        triage_status: 'duplicate', duplicate_of_review_id: nil)
    review.valid?
    expect(review.errors[:duplicate_of_review_id].join).to match(/required/i)
  end

  it 'rejects self-referencing duplicate' do
    review = Review.create!(action: 'comment', comment: 'dup', user: @p_viewer, rule: @p1r1)
    review.update(triage_status: 'duplicate', duplicate_of_review_id: review.id)
    expect(review.errors[:duplicate_of_review_id].join).to match(/cannot reference itself/i)
  end
end

describe 'responding_to_review_id invariants' do
  let!(:parent) {
    Review.create!(action: 'comment', comment: 'parent', user: @p_viewer, rule: @p1r1)
  }

  it 'rejects self-referencing reply' do
    response = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1)
    response.update(responding_to_review_id: response.id)
    expect(response.errors[:responding_to_review_id].join).to match(/cannot reference itself/i)
  end

  it 'links a reply via responding_to_review_id' do
    response = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                              responding_to_review_id: parent.id)
    expect(parent.reload.responses).to include(response)
  end

  it 'cascade-deletes responses when parent is deleted' do
    Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                   responding_to_review_id: parent.id)
    expect { parent.destroy }.to change(Review, :count).by(-2)
  end
end

describe 'auto-set adjudicated_at on terminal triage statuses' do
  %w[duplicate informational withdrawn].each do |status|
    it "sets adjudicated_at when triage_status becomes #{status}" do
      review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
      original_dup = Review.create!(action: 'comment', comment: 'orig', user: @p_viewer, rule: @p1r1)

      attrs = { triage_status: status, triage_set_by_id: @p_admin.id, triage_set_at: Time.current }
      attrs[:duplicate_of_review_id] = original_dup.id if status == 'duplicate'

      expect { review.update!(attrs) }
        .to change { review.reload.adjudicated_at }.from(nil).to(an_instance_of(ActiveSupport::TimeWithZone))
    end
  end
end

describe 'withdrawn auto-sets adjudicated_by_id to commenter' do
  it 'sets adjudicated_by_id to user_id (the commenter themselves)' do
    review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
    review.update!(triage_status: 'withdrawn')
    expect(review.reload.adjudicated_by_id).to eq(@p_viewer.id)
  end
end

describe 'scopes' do
  before do
    @c1 = Review.create!(action: 'comment', comment: 'one', user: @p_viewer, rule: @p1r1,
                         triage_status: 'pending')
    @c2 = Review.create!(action: 'comment', comment: 'two', user: @p_viewer, rule: @p1r1,
                         triage_status: 'concur', triage_set_by_id: @p_admin.id, triage_set_at: Time.current)
    @reply = Review.create!(action: 'comment', comment: 'reply', user: @p_admin, rule: @p1r1,
                            responding_to_review_id: @c1.id)
  end

  it 'top_level_comments excludes responses' do
    expect(Review.top_level_comments.where(rule: @p1r1)).to include(@c1, @c2)
    expect(Review.top_level_comments.where(rule: @p1r1)).not_to include(@reply)
  end

  it 'pending_triage returns only pending top-level comments' do
    expect(Review.pending_triage.where(rule: @p1r1)).to include(@c1)
    expect(Review.pending_triage.where(rule: @p1r1)).not_to include(@c2, @reply)
  end
end
```

## Step 2: Run the specs to verify they fail

```bash
bundle exec rspec spec/models/reviews_spec.rb -e "triage_status enum"
bundle exec rspec spec/models/reviews_spec.rb -e "section enum"
bundle exec rspec spec/models/reviews_spec.rb -e "duplicate_of_review_id"
bundle exec rspec spec/models/reviews_spec.rb -e "responding_to_review_id"
bundle exec rspec spec/models/reviews_spec.rb -e "auto-set adjudicated_at"
bundle exec rspec spec/models/reviews_spec.rb -e "withdrawn auto-sets"
bundle exec rspec spec/models/reviews_spec.rb -e "scopes"
```

**Expected:** all FAIL — none of the constants, validators, scopes, or auto-set callbacks exist yet.

## Step 3: Add constants + validators + auto-set callbacks + scopes to `app/models/review.rb`

Add **after** the existing `ACTION_PERMISSIONS`/`TIER_ROLES` (from Task 01) and **before** `validates :comment, :action, presence: true`:

```ruby
TRIAGE_STATUSES = %w[
  pending concur concur_with_comment non_concur
  duplicate informational needs_clarification withdrawn
].freeze

TERMINAL_AUTO_ADJUDICATE_STATUSES = %w[duplicate informational withdrawn].freeze

SECTION_KEYS = %w[
  title severity status fixtext check_content vuln_discussion
  disa_metadata vendor_comments artifact_description xccdf_metadata
].freeze

ALLOWED_SECTIONS = (SECTION_KEYS + [nil]).freeze

# Audit lifecycle changes for tamper-evident comment trail
include VulcanAuditable if defined?(VulcanAuditable)
vulcan_audited only: %i[triage_status adjudicated_at adjudicated_by_id
                         duplicate_of_review_id comment] if defined?(VulcanAuditable) && respond_to?(:vulcan_audited)

has_many :responses, class_name: 'Review', foreign_key: 'responding_to_review_id', dependent: :destroy
belongs_to :responding_to, class_name: 'Review', optional: true
belongs_to :duplicate_of, class_name: 'Review', foreign_key: 'duplicate_of_review_id', optional: true
belongs_to :triage_set_by, class_name: 'User', optional: true
belongs_to :adjudicated_by, class_name: 'User', optional: true
```

Add validations (before existing `before_create :take_review_action`):

```ruby
validates :triage_status, inclusion: { in: TRIAGE_STATUSES }
validates :section, inclusion: { in: ALLOWED_SECTIONS, allow_nil: true,
                                  message: 'is not a recognized section' }
validate :duplicate_status_requires_target
validate :no_self_responding_reference
validate :no_self_duplicate_reference

before_save :auto_set_adjudicated_for_terminal_statuses
```

Add scopes:

```ruby
scope :top_level_comments, -> { where(action: 'comment', responding_to_review_id: nil) }
scope :pending_triage, -> { top_level_comments.where(triage_status: 'pending') }
scope :awaiting_adjudication, -> {
  top_level_comments.where(triage_status: %w[concur concur_with_comment non_concur])
                    .where(adjudicated_at: nil)
}
```

Add the validator + callback methods (private):

```ruby
def duplicate_status_requires_target
  return unless triage_status == 'duplicate' && duplicate_of_review_id.blank?
  errors.add(:duplicate_of_review_id, 'is required when triage_status is duplicate')
end

def no_self_responding_reference
  return unless responding_to_review_id.present? && responding_to_review_id == id
  errors.add(:responding_to_review_id, 'cannot reference itself')
end

def no_self_duplicate_reference
  return unless duplicate_of_review_id.present? && duplicate_of_review_id == id
  errors.add(:duplicate_of_review_id, 'cannot reference itself')
end

def auto_set_adjudicated_for_terminal_statuses
  return unless TERMINAL_AUTO_ADJUDICATE_STATUSES.include?(triage_status)
  return if adjudicated_at.present?

  self.adjudicated_at = Time.current
  self.adjudicated_by_id ||= (triage_status == 'withdrawn' ? user_id : triage_set_by_id)
end
```

## Step 4: Run the specs to verify they pass

```bash
bundle exec rspec spec/models/reviews_spec.rb
```

**Expected:** all PASS — original tests + new tests.

If `VulcanAuditable` is not defined in the codebase, comment out those two `include`/`vulcan_audited` lines and surface to user — the audit feature is critical but might be named differently (the existing concern at `app/models/concerns/vulcan_auditable.rb` is referenced in CLAUDE.md). Check before reporting blocked:

```bash
ls app/models/concerns/vulcan_auditable.rb && grep -n "vulcan_audited" app/models/concerns/vulcan_auditable.rb
```

## Step 5: Verify the audit trail for triage_status changes

Quick smoke check in a Rails console-style spec:

```ruby
it 'audits triage_status changes' do
  review = Review.create!(action: 'comment', comment: 'x', user: @p_viewer, rule: @p1r1)
  expect { review.update!(triage_status: 'concur', triage_set_by_id: @p_admin.id, triage_set_at: Time.current) }
    .to change(review.audits, :count).by(1)
  audit = review.audits.last
  expect(audit.audited_changes['triage_status']).to eq(['pending', 'concur'])
end
```

Append to the same spec file. Run with `-e "audits"`.

## Step 6: Run RuboCop

```bash
bundle exec rubocop app/models/review.rb spec/models/reviews_spec.rb
```

**Expected:** 0 offenses.

## Step 7: Run the full backend suite

```bash
bundle exec parallel_rspec spec/
```

**Expected:** 0 failures.

## Step 8: Commit

```bash
cat > /tmp/msg-05.md <<'EOF'
feat: Review model validations + lifecycle invariants + audit trail

Wires up the model-layer logic for the lifecycle columns added in Task 04:

- TRIAGE_STATUSES enum (DISA matrix vocab) with inclusion validator
- SECTION_KEYS enum (XCCDF element keys) with NULL = general comment
- duplicate_status_requires_target — triage_status='duplicate' must point at a target
- no_self_responding_reference / no_self_duplicate_reference — self-FK guards
- auto_set_adjudicated_for_terminal_statuses — duplicate/informational/
  withdrawn auto-set adjudicated_at + adjudicated_by_id (commenter for
  withdrawn, triager for the others)
- has_many :responses (FK responding_to_review_id, dependent: :destroy)
- Scopes: top_level_comments, pending_triage, awaiting_adjudication
- VulcanAuditable wired up for triage_status, adjudicated_at,
  adjudicated_by_id, duplicate_of_review_id, comment — tamper-evident
  trail for the public-comment workflow

No controller wiring yet (Tasks 08-12).

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/models/review.rb spec/models/reviews_spec.rb
git commit -F /tmp/msg-05.md
rm /tmp/msg-05.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/05-review-model-validations.md \
       docs/plans/PR717-public-comment-review/05-review-model-validations-DONE.md
git commit -m "chore: mark plan task 05 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- All lifecycle invariants enforced at the model layer
- Audit trail capturing triage decisions for every Review
- Auto-set rules eliminate manual `adjudicated_at` for terminal-by-rule statuses
- Scopes (`top_level_comments`, `pending_triage`, `awaiting_adjudication`) ready for controller queries in Tasks 08-12
