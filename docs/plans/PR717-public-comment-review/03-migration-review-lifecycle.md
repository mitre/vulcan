# Task 03: Migration — Review lifecycle columns

**Depends on:** —
**Unblocks:** 05, 08, 09, 10, 11, 12
**Estimate:** 20 min Claude-pace
**File touches:**
- `db/migrate/<timestamp>_add_lifecycle_columns_to_reviews.rb` (new migration)
- `db/schema.rb` (regenerated)

Adds the lifecycle columns on Review described in design doc §3.3. **DISA-native vocabulary on the wire** per §3.1.1. No frontend wiring yet.

---

## Step 1: Generate the migration

```bash
bin/rails generate migration AddLifecycleColumnsToReviews
```

This creates `db/migrate/<timestamp>_add_lifecycle_columns_to_reviews.rb`.

## Step 2: Write the migration body

Replace the generated body with:

```ruby
class AddLifecycleColumnsToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :triage_status, :string, default: 'pending', null: false
    # values: pending | concur | concur_with_comment | non_concur
    #       | duplicate | informational | needs_clarification | withdrawn

    add_column :reviews, :triage_set_by_id, :bigint
    add_column :reviews, :triage_set_at, :datetime
    add_column :reviews, :adjudicated_at, :datetime
    add_column :reviews, :adjudicated_by_id, :bigint
    add_column :reviews, :duplicate_of_review_id, :bigint
    add_column :reviews, :responding_to_review_id, :bigint
    add_column :reviews, :section, :string  # XCCDF element key; NULL = general

    add_index :reviews, [:action, :triage_status]
    add_index :reviews, [:rule_id, :section, :triage_status]
    add_index :reviews, :responding_to_review_id
    add_index :reviews, :duplicate_of_review_id
    add_index :reviews, :user_id unless index_exists?(:reviews, :user_id)

    add_foreign_key :reviews, :users,   column: :triage_set_by_id,         on_delete: :nullify
    add_foreign_key :reviews, :users,   column: :adjudicated_by_id,        on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :duplicate_of_review_id,   on_delete: :nullify
    add_foreign_key :reviews, :reviews, column: :responding_to_review_id,  on_delete: :cascade
  end
end
```

Notes:
- `default: 'pending', null: false` backfills all existing Review rows in one statement. Vulcan's per-project review counts are low thousands; this is safe in a single transaction.
- `[:rule_id, :section, :triage_status]` composite index drives both the per-rule dedup query and the triage-queue-scoped-to-a-rule query.
- `responding_to_review_id` cascades on parent delete (replies are inseparable from the comment they answer).
- `duplicate_of_review_id` nullifies on target delete (a duplicate's pointer becomes invalid but the duplicate itself still exists for audit).
- `index_exists?` guard on `user_id` keeps this idempotent if the column already has an index.

## Step 3: Write a sanity spec for the migration

Create or extend `spec/migrations/add_lifecycle_columns_to_reviews_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AddLifecycleColumnsToReviews migration' do
  it 'adds the expected columns with correct defaults' do
    review = Review.new(action: 'comment', comment: 'x', user_id: 1, rule_id: 1)
    expect(review).to respond_to(:triage_status)
    expect(review).to respond_to(:triage_set_by_id)
    expect(review).to respond_to(:triage_set_at)
    expect(review).to respond_to(:adjudicated_at)
    expect(review).to respond_to(:adjudicated_by_id)
    expect(review).to respond_to(:duplicate_of_review_id)
    expect(review).to respond_to(:responding_to_review_id)
    expect(review).to respond_to(:section)

    expect(review.triage_status).to eq('pending') # default
  end

  it 'has the expected indexes' do
    indexes = ActiveRecord::Base.connection.indexes(:reviews).map(&:columns)
    expect(indexes).to include(%w[action triage_status])
    expect(indexes).to include(%w[rule_id section triage_status])
    expect(indexes).to include(['responding_to_review_id'])
    expect(indexes).to include(['duplicate_of_review_id'])
  end
end
```

## Step 4: Run the migration

```bash
bin/rails db:migrate
bundle exec rake parallel:prepare    # CRITICAL: sync to all parallel test DBs
```

**Expected:** migrations apply cleanly, parallel test DBs are in sync. If `parallel:prepare` is skipped, the parallel test runs will fail mysteriously.

## Step 5: Run the sanity spec

```bash
bundle exec rspec spec/migrations/add_lifecycle_columns_to_reviews_spec.rb
```

**Expected:** PASS.

## Step 6: Run the full backend test suite (parallel)

```bash
bundle exec parallel_rspec spec/
```

**Expected:** 0 failures. The new columns being NULL on existing reviews shouldn't break anything; `triage_status='pending'` is a backfilled default that's correct for non-comment reviews too (they're effectively "untriaged" but the column is meaningless for them — that's fine).

## Step 7: Verify schema.rb is updated

```bash
git diff db/schema.rb
```

**Expected:** schema.rb shows the 8 new columns + 4 new indexes + 4 new FKs in the `reviews` table.

## Step 8: Commit

```bash
cat > /tmp/msg-03.md <<'EOF'
feat: add lifecycle columns to reviews for triage workflow

Migration adds 8 columns to support the public comment review workflow
(see design.md §3.3):

- triage_status (string, default 'pending', not null) — DISA matrix vocab
- triage_set_by_id, triage_set_at — who triaged, when
- adjudicated_at, adjudicated_by_id — who closed, when
- duplicate_of_review_id — self-FK, nullify on target delete
- responding_to_review_id — self-FK, cascade on parent delete
- section — XCCDF element key (nullable; NULL = general comment)

Indexes:
- [action, triage_status] — triage queue queries
- [rule_id, section, triage_status] — per-rule per-section dedup +
  rule-scoped triage queries
- responding_to_review_id, duplicate_of_review_id — FK lookup paths

Backfill of triage_status='pending' on existing rows is safe at Vulcan's
review-count scale (low thousands per project).

No model logic yet — Task 05 wires up validators, audited gem, and
auto-set rules. No controller/UI changes yet.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add db/migrate/*_add_lifecycle_columns_to_reviews.rb db/schema.rb \
        spec/migrations/add_lifecycle_columns_to_reviews_spec.rb
git commit -F /tmp/msg-03.md
rm /tmp/msg-03.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/03-migration-review-lifecycle.md \
       docs/plans/PR717-public-comment-review/03-migration-review-lifecycle-DONE.md
git commit -m "chore: mark plan task 03 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```

---

## What's done after this task

- All lifecycle columns exist on `reviews` table
- Indexes in place for the table-driving queries
- FK constraints with appropriate `on_delete` semantics
- Existing model logic still works (columns are NULL/default; nothing references them yet)
- Foundation for Task 05 (validators) and Tasks 08-12 (controller endpoints)
