# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Rails/SkipsModelValidations -- test setup deliberately bypasses validations
# to create specific DB states (stale FKs, nil user_id, imported attribution)
RSpec.describe Review do
  include_context 'srg model base setup'

  describe 'scopes' do
    before do
      @c1 = create(:review, :comment, comment: 'one', section: nil, user: p_viewer, rule: rule,
                                      triage_status: 'pending')
      @c2 = create(:review, :comment, comment: 'two', section: nil, user: p_viewer, rule: rule,
                                      triage_status: 'concur', triage_set_by_id: p_admin.id, triage_set_at: Time.current)
      @reply = create(:review, :comment, comment: 'reply', section: nil, user: p_admin, rule: rule,
                                         responding_to_review_id: @c1.id)
    end

    it 'top_level_comments excludes responses' do
      expect(Review.top_level_comments.where(rule: rule)).to include(@c1, @c2)
      expect(Review.top_level_comments.where(rule: rule)).not_to include(@reply)
    end

    it 'pending_triage returns only pending top-level comments' do
      expect(Review.pending_triage.where(rule: rule)).to include(@c1)
      expect(Review.pending_triage.where(rule: rule)).not_to include(@c2, @reply)
    end

    # the original lifecycle migration set
    # triage_status NOT NULL DEFAULT 'pending'. On systems with pre-PR-717
    # `comment` reviews (action='comment' rows that were never part of a
    # public-comment workflow), every legacy row dumps into the triage
    # queue as "pending". DISA reviewers see unrelated historical content.
    # Fix: drop the DB default, allow NULL on the column, backfill legacy
    # rows (rows on rules in components that never opened a public-comment
    # period) to NULL. The pending_triage scope already filters by
    # `triage_status: 'pending'` (Rails treats NULL ≠ 'pending'), so the
    # behavior change is data-only — but we add a defensive
    # `where.not(triage_status: nil)` clause for explicit intent.
    context 'with legacy reviews (NULL triage_status)' do
      let!(:legacy_comment) do
        review = create(:review, :comment, comment: 'legacy', section: nil, user: p_viewer, rule: rule,
                                           triage_status: 'pending')
        # Simulate the legacy state directly. update_columns bypasses
        # validators + callbacks; the DB-level NOT NULL constraint must
        # be dropped by the migration before this can succeed.
        review.update_columns(triage_status: nil)
        review
      end

      it 'pending_triage excludes legacy comments with NULL triage_status' do
        expect(Review.pending_triage.where(rule: rule)).not_to include(legacy_comment)
      end

      it 'allows NULL on triage_status at the DB layer' do
        # Reload to confirm the value persisted; would raise
        # ActiveRecord::StatementInvalid (NotNullViolation) on update_columns
        # in the legacy_comment let! if the column were still NOT NULL.
        expect(legacy_comment.reload.triage_status).to be_nil
      end

      it 'passes validation with triage_status nil' do
        # Without allow_nil on the inclusion validator, save would fail
        # with "Triage status is not included in the list" once a code
        # path tries to validate a NULL row (e.g. update through the model
        # with a different attribute).
        legacy_comment.reload
        expect(legacy_comment).to be_valid
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
