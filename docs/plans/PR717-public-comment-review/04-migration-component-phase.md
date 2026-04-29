# Task 04: Migration — Component comment phase

**Depends on:** —
**Unblocks:** 21, 22
**Estimate:** 10 min Claude-pace
**File touches:**
- `db/migrate/<timestamp>_add_comment_phase_to_components.rb`
- `app/models/component.rb` (helpers)
- `spec/models/component_spec.rb` (coverage for helpers)

Adds the comment-period phase enum on Component (design doc §3.5.1). Independent of Task 03 — can run in parallel.

---

## Step 1: Generate migration

```bash
bin/rails generate migration AddCommentPhaseToComponents
```

## Step 2: Write migration body

```ruby
class AddCommentPhaseToComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :components, :comment_phase, :string, default: 'draft', null: false
    # values: draft | open | adjudication | final
    add_column :components, :comment_period_starts_at, :datetime
    add_column :components, :comment_period_ends_at, :datetime

    add_index :components, :comment_phase
    add_index :components, [:comment_period_starts_at, :comment_period_ends_at],
              name: 'index_components_on_comment_period_dates'
  end
end
```

Notes:
- `notify_commenters_on_*` booleans are deliberately omitted — email is deferred to v2 (design §3.6).
- `default: 'draft'` means existing components default to "not accepting comments" — safe baseline. Admins flip to `open` explicitly.

## Step 3: Run migration

```bash
bin/rails db:migrate
bundle exec rake parallel:prepare
```

## Step 4: Write failing model spec

Append to `spec/models/component_spec.rb`:

```ruby
describe 'comment phase' do
  let(:component) { create(:component) }

  it 'defaults to draft' do
    expect(component.comment_phase).to eq('draft')
  end

  it 'rejects an invalid phase' do
    component.comment_phase = 'whatever'
    expect(component).not_to be_valid
    expect(component.errors[:comment_phase].join).to match(/included in the list/i)
  end

  describe '#accepting_new_comments?' do
    it 'is true only when phase is open' do
      component.comment_phase = 'open'
      expect(component.accepting_new_comments?).to eq(true)
      %w[draft adjudication final].each do |phase|
        component.comment_phase = phase
        expect(component.accepting_new_comments?).to eq(false), "unexpectedly true for #{phase}"
      end
    end
  end

  describe '#triaging_active?' do
    it 'is true for open and adjudication' do
      %w[open adjudication].each do |phase|
        component.comment_phase = phase
        expect(component.triaging_active?).to eq(true), "unexpectedly false for #{phase}"
      end
      %w[draft final].each do |phase|
        component.comment_phase = phase
        expect(component.triaging_active?).to eq(false), "unexpectedly true for #{phase}"
      end
    end
  end

  describe '#comment_period_days_remaining' do
    it 'returns nil when phase is not open' do
      component.comment_phase = 'draft'
      component.comment_period_ends_at = 5.days.from_now
      expect(component.comment_period_days_remaining).to be_nil
    end

    it 'returns days remaining when open with an end date' do
      component.comment_phase = 'open'
      component.comment_period_ends_at = 5.days.from_now
      expect(component.comment_period_days_remaining).to eq(5)
    end

    it 'returns nil when open without an end date' do
      component.comment_phase = 'open'
      component.comment_period_ends_at = nil
      expect(component.comment_period_days_remaining).to be_nil
    end
  end
end
```

## Step 5: Run the spec to verify it fails

```bash
bundle exec rspec spec/models/component_spec.rb -e "comment phase"
```

**Expected:** all examples FAIL (helpers don't exist yet, no inclusion validation).

## Step 6: Add the helpers to Component

In `app/models/component.rb`, add near the top of the class body (after associations, before existing validations):

```ruby
COMMENT_PHASES = %w[draft open adjudication final].freeze
validates :comment_phase, inclusion: { in: COMMENT_PHASES }

def accepting_new_comments?
  comment_phase == 'open'
end

def triaging_active?
  %w[open adjudication].include?(comment_phase)
end

def comment_period_days_remaining
  return nil unless comment_phase == 'open' && comment_period_ends_at

  ((comment_period_ends_at - Time.current) / 1.day).ceil
end
```

## Step 7: Run the spec to verify it passes

```bash
bundle exec rspec spec/models/component_spec.rb -e "comment phase"
```

**Expected:** all PASS.

## Step 8: Run the full component spec to confirm no regressions

```bash
bundle exec rspec spec/models/component_spec.rb
```

**Expected:** 0 failures.

## Step 9: RuboCop

```bash
bundle exec rubocop app/models/component.rb db/migrate/*_add_comment_phase_to_components.rb spec/models/component_spec.rb
```

**Expected:** 0 offenses.

## Step 10: Commit

```bash
cat > /tmp/msg-04.md <<'EOF'
feat: add comment_phase enum to Component for public comment workflow

Adds three columns on components:
- comment_phase: draft | open | adjudication | final (default 'draft')
- comment_period_starts_at / comment_period_ends_at: datetimes

The phased model lets the Container SRG team move from draft → open
(accepting comments + triaging) → adjudication (no new comments, triage
continues) → final (read-only archive). New comment posts check
accepting_new_comments?; triage/adjudicate endpoints check
triaging_active?.

Email notification toggles are deliberately omitted — outbound email is
deferred to v2 along with the rest of the email infrastructure (see
DESIGN §3.6 for rationale).

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add db/migrate/*_add_comment_phase_to_components.rb db/schema.rb \
        app/models/component.rb spec/models/component_spec.rb
git commit -F /tmp/msg-04.md
rm /tmp/msg-04.md
```

## Step 11: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/04-migration-component-phase.md \
       docs/plans/PR717-public-comment-review/04-migration-component-phase-DONE.md
git commit -m "chore: mark plan task 04 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- `Component#comment_phase` enum + helpers (`accepting_new_comments?`, `triaging_active?`, `comment_period_days_remaining`)
- Default-`draft` state on existing components — safe baseline
- Foundation for Task 21 (banner) and Task 22 (UpdateComponentDetailsModal fieldset)
