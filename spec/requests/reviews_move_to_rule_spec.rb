# frozen_string_literal: true

require 'rails_helper'

# PATCH /reviews/:id/move_to_rule.
# Admin reassigns a misplaced comment (and atomically, all its replies)
# to a different rule in the same component. Audit-comment required.
# Walks parent-first so the responding_to_must_be_same_rule validator
# sees the parent already at the target when each child moves.
RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

  describe 'PATCH /reviews/:id/move_to_rule' do
    let_it_be(:mtr_admin) { create(:user) }
    let_it_be(:mtr_author) { create(:user) }
    let_it_be(:mtr_commenter) { create(:user) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:other_component) { create(:component, project: other_project, based_on: srg) }

    before_all do
      Membership.find_or_create_by!(user: mtr_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: mtr_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: mtr_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let(:rule_a) { component.rules.first }
    let(:rule_b) { component.rules.second }
    let(:rule_other_component) { other_component.rules.first }

    let!(:parent_review) do
      create(:review, :comment, comment: 'misplaced concern', section: nil, user: mtr_commenter, rule: rule_a,
                                triage_status: 'pending')
    end
    let!(:reply_review) do
      create(:review, :comment, comment: 'thanks for raising', section: nil, user: mtr_author, rule: rule_a,
                                responding_to_review_id: parent_review.id)
    end
    # reply-of-reply, exercises depth>=2 in
    # move_review_subtree!. Without this, a regression that only descended
    # one level (e.g. responses.first&.update! instead of recursion) would
    # pass the original test.
    let!(:nested_reply_review) do
      create(:review, :comment, comment: 'follow-up to the reply', section: nil, user: mtr_commenter, rule: rule_a,
                                responding_to_review_id: reply_review.id)
    end

    context 'as project admin' do
      before { sign_in mtr_admin }

      it 'reassigns the parent review and ALL replies (including reply-of-reply) to the target rule' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'belongs on rule B' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(parent_review.reload.rule_id).to eq(rule_b.id)
        expect(reply_review.reload.rule_id).to eq(rule_b.id)
        expect(nested_reply_review.reload.rule_id).to eq(rule_b.id)
      end

      it 'rejects when target rule is in a different component' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_other_component.id, audit_comment: 'cross-component attempt' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(parent_review.reload.rule_id).to eq(rule_a.id)
        # toast variant must be a valid Bootstrap-Vue
        # value (success/warning/danger/info). The original code shipped
        # 'unprocessable_content' which renders an unstyled toast.
        expect(response.parsed_body.dig('toast', 'variant')).to eq('warning')
      end

      it 'rejects when target rule is the same as the source rule' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_a.id, audit_comment: 'no-op' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects when target rule does not exist' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: 999_999, audit_comment: 'nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'preserves triage_status and adjudication on move' do
        parent_review.update!(triage_status: 'concur',
                              adjudicated_at: 1.day.ago,
                              adjudicated_by_id: mtr_author.id)
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'reassigning' }, as: :json
        expect(response).to have_http_status(:ok)

        parent_review.reload
        expect(parent_review.rule_id).to eq(rule_b.id)
        expect(parent_review.triage_status).to eq('concur')
        expect(parent_review.adjudicated_at).to be_present
      end

      it 'records the rule_id change in the audit trail (vulcan_audited only must include rule_id)' do
        expect do
          patch "/reviews/#{parent_review.id}/move_to_rule",
                params: { rule_id: rule_b.id, audit_comment: 'audit-trail check' }, as: :json
        end.to change { parent_review.reload.audits.count }.by_at_least(1)
        latest = parent_review.audits.last
        expect(latest.audited_changes['rule_id']).to eq([rule_a.id, rule_b.id])
      end

      # outbound audit on the SOURCE rule.
      # vulcan_audited associated_with: :rule attaches per-review audit
      # rows to the NEW rule (after the update). Reviewers auditing the
      # source rule's history would see nothing about the move. The
      # source-side audit closes that forensic asymmetry: a separate
      # audit row attached to the source rule, action='review_moved_out',
      # carrying review_id + source_rule_id + destination_rule_id +
      # reply_count + the operator's audit_comment.
      it 'writes an outbound audit on the source rule with action=review_moved_out' do
        expect do
          patch "/reviews/#{parent_review.id}/move_to_rule",
                params: { rule_id: rule_b.id, audit_comment: 'forensic outbound check' }, as: :json
        end.to change {
          rule_a.audits.where(action: 'review_moved_out').count
        }.by(1)
      end

      it 'outbound audit captures source/destination rule_ids + review_id + reply_count' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'payload check' }, as: :json
        outbound = rule_a.audits.where(action: 'review_moved_out').last
        expect(outbound).to be_present
        # Audited stores manually-passed audited_changes hashes via YAML
        # round-trip with symbol keys (mirrors the F4 destroyed_review_
        # snapshots assertion in the .4 admin_destroy spec).
        expect(outbound.audited_changes[:review_id]).to eq(parent_review.id)
        expect(outbound.audited_changes[:source_rule_id]).to eq(rule_a.id)
        expect(outbound.audited_changes[:destination_rule_id]).to eq(rule_b.id)
        expect(outbound.audited_changes[:reply_count]).to eq(parent_review.responses.count)
      end

      it 'outbound audit carries the operator audit_comment in its comment' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'misclassified — moving' }, as: :json
        outbound = rule_a.audits.where(action: 'review_moved_out').last
        expect(outbound.comment).to include('misclassified — moving')
      end

      it 'outbound audit attributed to the operating admin' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'attribution check' }, as: :json
        outbound = rule_a.audits.where(action: 'review_moved_out').last
        expect(outbound.user_id).to eq(mtr_admin.id)
      end

      # concurrent admin race fix.
      # Same lock! pattern as admin_destroy: SELECT FOR UPDATE inside the
      # Review.transaction block so a concurrent move_to_rule or
      # admin_destroy on the same subtree waits for ours to commit.
      it 'acquires a row lock on @review at the start of the action' do
        expect_any_instance_of(Review).to receive(:lock!).at_least(:once).and_call_original
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'lock test' }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a non-admin author' do
      before { sign_in mtr_author }

      it 'returns 403 and leaves the rule_id unchanged' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'unauthorized' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(parent_review.reload.rule_id).to eq(rule_a.id)
      end
    end
  end
end
