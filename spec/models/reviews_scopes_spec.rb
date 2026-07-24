# frozen_string_literal: true

require 'rails_helper'

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
  end

  # REQUIREMENT: the review-notification recipient (mail + Slack) is the
  # user who filed the LATEST review request on the requirement row —
  # kind-shared (reviews.rule_id is the base_rules PK), so authored SRG
  # requirements resolve exactly like STIG requirements.
  describe '.latest_requestor_for' do
    it 'returns the latest requestor for a STIG requirement' do
      first = create(:review, user: p_author, rule: rule, action: 'request_review',
                              comment: 'first request')
      first.update_column(:updated_at, 2.days.ago)
      # A second request is only valid after the first is closed out.
      create(:review, user: p_author, rule: rule, action: 'revoke_review_request',
                      comment: 'withdrawing')
      create(:review, user: p_admin, rule: rule, action: 'request_review',
                      comment: 'latest request')

      expect(Review.latest_requestor_for(rule)).to eq(p_admin)
    end

    it 'returns the requestor for an authored SRG requirement' do
      core_srg = create(:security_requirements_guide, :core, :skip_rules,
                        srg_id: 'SRG-CORE-SCOPES', version: 'V1R1')
      srg_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                      based_on: core_srg, prefix: 'SCOP-00')
      srg_requirement = create(:srg_rule, :authored, component: srg_component, rule_id: '940001')
      create(:review, rule: nil, commentable: srg_requirement, user: p_author,
                      action: 'request_review', comment: 'srg request')

      expect(Review.latest_requestor_for(srg_requirement)).to eq(p_author)
    end

    it 'returns nil when no review was ever requested' do
      expect(Review.latest_requestor_for(rule)).to be_nil
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

    describe '.awaiting_adjudication' do
      it 'includes concur review with nil adjudicated_at' do
        review = create(:review, :comment, comment: 'x', section: nil, user: p_viewer, rule: rule)
        review.update!(triage_status: 'concur', triage_set_by_id: p_admin.id, triage_set_at: Time.current,
                       adjudicated_at: nil, adjudicated_by_id: nil)
        review.save_intent = :reopen
        review.update!(adjudicated_at: nil, adjudicated_by_id: nil)
        expect(Review.awaiting_adjudication.pluck(:id)).to include(review.id)
      end

      it 'excludes concur review with adjudicated_at present' do
        review = create(:review, :comment, comment: 'x', section: nil, user: p_viewer, rule: rule)
        review.update!(triage_status: 'concur', triage_set_by_id: p_admin.id, triage_set_at: Time.current,
                       adjudicated_at: Time.current, adjudicated_by_id: p_admin.id)
        expect(Review.awaiting_adjudication.pluck(:id)).not_to include(review.id)
      end

      it 'excludes pending reviews' do
        review = create(:review, :comment, comment: 'x', section: nil, user: p_viewer, rule: rule)
        expect(Review.awaiting_adjudication.pluck(:id)).not_to include(review.id)
      end

      it 'excludes replies' do
        parent = create(:review, :comment, comment: 'p', section: nil, user: p_viewer, rule: rule)
        reply = create(:review, :comment, comment: 'r', section: nil, user: p_admin, rule: rule,
                                          responding_to_review_id: parent.id)
        expect(Review.awaiting_adjudication.pluck(:id)).not_to include(reply.id)
      end
    end
  end
end
