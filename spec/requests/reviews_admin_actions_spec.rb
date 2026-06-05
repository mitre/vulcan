# frozen_string_literal: true

require 'rails_helper'

# admin actions on a comment.
# Force-withdraw lets a project admin override the commenter's intent
# (spam, PII, policy violations, withdrawn-account cleanup). Audit
# comment is required so the audit trail captures the
# documented reason for the override.
# Restore is the inverse — undo a force-withdraw (or any prior
# adjudication) so the comment can be re-triaged. Same admin gate +
# audit comment requirement.
RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

  describe 'PATCH /reviews/:id/admin_withdraw' do
    let_it_be(:adm_admin) { create(:user) }
    let_it_be(:adm_author) { create(:user) }
    let_it_be(:adm_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: adm_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: adm_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: adm_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:target_review) do
      create(:review, :comment, comment: 'spam content', section: nil, user: adm_commenter, rule: rule)
    end

    context 'as project admin' do
      before { sign_in adm_admin }

      it 'sets triage_status=withdrawn + adjudicated attribution to admin + persists audit comment' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'spam content removed by admin' }, as: :json
        expect(response).to have_http_status(:ok)

        target_review.reload
        expect(target_review.triage_status).to eq('withdrawn')
        expect(target_review.adjudicated_at).to be_present
        expect(target_review.adjudicated_by_id).to eq(adm_admin.id)
        expect(target_review.audits.last.comment).to include('spam content removed')
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      # defense-in-depth length cap.
      # 4096 chars is the AUDIT_COMMENT_MAX_LENGTH constant on the controller.
      it 'accepts a 4096-char audit_comment' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'x' * 4096 }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'rejects a 4097-char audit_comment with 422' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'x' * 4097 }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'title')).to match(/too long/i)
      end

      it 'allows overriding an already-adjudicated review' do
        target_review.update!(triage_status: 'concur',
                              adjudicated_at: 1.day.ago,
                              adjudicated_by_id: adm_author.id)
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'overriding prior decision' }, as: :json
        expect(response).to have_http_status(:ok)
        target_review.reload
        expect(target_review.triage_status).to eq('withdrawn')
        expect(target_review.adjudicated_by_id).to eq(adm_admin.id)
      end

      it 'is allowed even when the component is closed+finalized (frozen)' do
        component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'PII cleanup post-window' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(target_review.reload.triage_status).to eq('withdrawn')
      ensure
        component.update_columns(comment_phase: 'open', closed_reason: nil)
      end
    end

    context 'as a non-admin author' do
      before { sign_in adm_author }

      it 'returns 403 and leaves the comment unchanged' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'should be rejected' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(target_review.reload.triage_status).to eq('pending')
      end
    end

    context 'as the commenter (not admin)' do
      before { sign_in adm_commenter }

      it 'returns 403' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'self-override should be rejected' }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /reviews/:id/admin_restore' do
    let_it_be(:adm_r_admin) { create(:user) }
    let_it_be(:adm_r_author) { create(:user) }
    let_it_be(:adm_r_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: adm_r_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: adm_r_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: adm_r_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:withdrawn_review) do
      r = create(:review, :comment, comment: 'something', section: nil, user: adm_r_commenter, rule: rule)
      r.update!(triage_status: 'withdrawn',
                adjudicated_at: 1.hour.ago,
                adjudicated_by_id: adm_r_admin.id)
      r
    end

    context 'as project admin' do
      before { sign_in adm_r_admin }

      it 'reverts triage_status to pending and clears adjudicated_at + adjudicated_by_id' do
        patch "/reviews/#{withdrawn_review.id}/admin_restore",
              params: { audit_comment: 'restoring — withdrew the wrong review' }, as: :json
        expect(response).to have_http_status(:ok)

        withdrawn_review.reload
        expect(withdrawn_review.triage_status).to eq('pending')
        expect(withdrawn_review.adjudicated_at).to be_nil
        expect(withdrawn_review.adjudicated_by_id).to be_nil
        expect(withdrawn_review.audits.last.comment).to include('restoring')
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{withdrawn_review.id}/admin_restore",
              params: { audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects restoring a non-adjudicated comment (nothing to restore from)' do
        pending_review = create(:review, :comment, comment: 'still pending', section: nil,
                                                   user: adm_r_commenter, rule: rule)
        patch "/reviews/#{pending_review.id}/admin_restore",
              params: { audit_comment: 'no-op attempt' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'restores a review previously triaged as duplicate — clears all triage + adjudication fields' do
        survivor = create(:review, :comment, comment: 'survivor', section: nil,
                                             user: adm_r_commenter, rule: rule)
        dup_review = create(:review, :comment, comment: 'marked dup', section: nil,
                                               user: adm_r_commenter, rule: rule)
        dup_review.update!(triage_status: 'duplicate', duplicate_of_review_id: survivor.id,
                           triage_set_by_id: adm_r_admin.id, triage_set_at: Time.current,
                           adjudicated_at: Time.current, adjudicated_by_id: adm_r_admin.id)

        patch "/reviews/#{dup_review.id}/admin_restore",
              params: { audit_comment: 'undo duplicate decision' }, as: :json

        expect(response).to have_http_status(:ok)
        dup_review.reload
        expect(dup_review.triage_status).to eq('pending')
        expect(dup_review.duplicate_of_review_id).to be_nil
        expect(dup_review.adjudicated_at).to be_nil
        expect(dup_review.adjudicated_by_id).to be_nil
        expect(dup_review.triage_set_by_id).to be_nil
        expect(dup_review.triage_set_at).to be_nil
      end

      it 'restores a review previously triaged as addressed_by — clears all triage + adjudication fields' do
        ab_review = create(:review, :comment, comment: 'marked addressed', section: nil,
                                              user: adm_r_commenter, rule: rule)
        ab_review.update!(triage_status: 'addressed_by', addressed_by_rule_id: rule.id,
                          triage_set_by_id: adm_r_admin.id, triage_set_at: Time.current,
                          adjudicated_at: Time.current, adjudicated_by_id: adm_r_admin.id)

        patch "/reviews/#{ab_review.id}/admin_restore",
              params: { audit_comment: 'undo addressed_by decision' }, as: :json

        expect(response).to have_http_status(:ok)
        ab_review.reload
        expect(ab_review.triage_status).to eq('pending')
        expect(ab_review.addressed_by_rule_id).to be_nil
        expect(ab_review.adjudicated_at).to be_nil
        expect(ab_review.adjudicated_by_id).to be_nil
        expect(ab_review.triage_set_by_id).to be_nil
        expect(ab_review.triage_set_at).to be_nil
      end
    end

    context 'as a non-admin author' do
      before { sign_in adm_r_author }

      it 'returns 403 and leaves the comment withdrawn' do
        patch "/reviews/#{withdrawn_review.id}/admin_restore",
              params: { audit_comment: 'unauthorized restore attempt' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(withdrawn_review.reload.triage_status).to eq('withdrawn')
      end
    end
  end

  # DELETE /reviews/:id/admin_destroy.
  # Irreversible hard-delete of a comment + its reply subtree (dependent
  # destroy cascade). Federal-compliance audit entry created on the
  # COMPONENT before the destroy so the trail survives the deletion.
  describe 'DELETE /reviews/:id/admin_destroy' do
    let_it_be(:adm_d_admin) { create(:user) }
    let_it_be(:adm_d_author) { create(:user) }
    let_it_be(:adm_d_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: adm_d_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: adm_d_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: adm_d_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:doomed_review) do
      create(:review, :comment, comment: 'PII content', section: nil, user: adm_d_commenter, rule: rule)
    end
    let!(:reply_to_doomed) do
      create(:review, :comment, comment: 'reply text', section: nil, user: adm_d_author, rule: rule,
                                responding_to_review_id: doomed_review.id)
    end

    context 'as project admin' do
      before { sign_in adm_d_admin }

      it 'destroys the review AND its reply subtree (dependent: :destroy cascade)' do
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'PII removed per legal request' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(Review.exists?(doomed_review.id)).to be(false)
        expect(Review.exists?(reply_to_doomed.id)).to be(false)
      end

      # canonicalize admin_destroy
      # response shape. Pre-fix returned `{ok: true}` — only PR-717
      # endpoint not following the `{review: ...}` convention. Frontend
      # never reads the body, but a uniform shape lets the AlertMixin
      # / refresh logic stay generic across actions.
      it 'returns canonical {review: nil, destroyed_id: <id>} shape' do
        target_id = doomed_review.id
        delete "/reviews/#{target_id}/admin_destroy",
               params: { audit_comment: 'shape check' }, as: :json
        body = response.parsed_body
        expect(body).to have_key('review')
        expect(body['review']).to be_nil
        expect(body['destroyed_id']).to eq(target_id)
      end

      it 'rejects when audit_comment is blank' do
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(Review.exists?(doomed_review.id)).to be(true)
      end

      it 'records an audit entry on the COMPONENT (so the trail survives the destroy)' do
        component_id = doomed_review.rule.component_id
        before_count = Audited::Audit.where(auditable_type: 'Component', auditable_id: component_id).count
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'cleanup' }, as: :json
        after_count = Audited::Audit.where(auditable_type: 'Component', auditable_id: component_id).count
        expect(after_count).to be > before_count
        latest = Audited::Audit.where(auditable_type: 'Component', auditable_id: component_id).last
        expect(latest.action).to eq('admin_destroy_review')
        expect(latest.comment).to include('cleanup')
        expect(latest.user_id).to eq(adm_d_admin.id)
      end

      # FK swap regression test.
      # With FK on_delete: :restrict on responding_to_review_id, Rails
      # `dependent: :destroy` MUST walk the reply tree children-first
      # (recursively) so the parent delete doesn't violate the FK. This
      # test exercises a 3-level chain (parent → child → grandchild) AND
      # asserts every destroy event ends up sharing one request_uuid with
      # the operator's Component-level admin_destroy_review audit row —
      # the request_uuid correlation primitive AuditEventBundle uses for
      # forensic reconstruction.
      it 'cascades parent + child + grandchild via Rails callbacks; all events share one request_uuid' do
        grandchild = create(:review, :comment, comment: 'grandchild', section: nil,
                                               user: adm_d_commenter, rule: rule,
                                               responding_to_review_id: reply_to_doomed.id)
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'cascade-correlation test' }, as: :json
        expect(response).to have_http_status(:ok)
        # All three reviews destroyed
        expect(Review.exists?(doomed_review.id)).to be(false)
        expect(Review.exists?(reply_to_doomed.id)).to be(false)
        expect(Review.exists?(grandchild.id)).to be(false)
        # Per-Review destroy events captured by audited gem (proves Rails
        # callback path fired, not silent SQL cascade)
        per_review_destroys = Audited::Audit.where(
          action: 'destroy', auditable_type: 'Review',
          auditable_id: [doomed_review.id, reply_to_doomed.id, grandchild.id]
        )
        expect(per_review_destroys.count).to eq(3)
        # Component-level admin_destroy_review row + all 3 per-Review
        # destroys share one request_uuid (forensic correlation primitive)
        component_audit = Audited::Audit.where(
          auditable_type: 'Component', action: 'admin_destroy_review'
        ).where('comment LIKE ?', '%cascade-correlation test%').last
        expect(component_audit).to be_present
        expect(component_audit.request_uuid).to be_present
        expect(per_review_destroys.pluck(:request_uuid).uniq).to eq([component_audit.request_uuid])
      end

      # FK semantics. Constraint must
      # be on_delete: :restrict so Rails owns the cascade (callbacks +
      # audited destroy events fire); FK is a safety net against bypass.
      it 'has FK responding_to_review_id with on_delete: :restrict' do
        fk = ActiveRecord::Base.connection.foreign_keys('reviews').find do |k|
          k.column == 'responding_to_review_id'
        end
        expect(fk).to be_present
        expect(fk.on_delete).to eq(:restrict)
      end

      # concurrent admin race fix.
      # Two admins simultaneously: one moves a review subtree, the other
      # hard-deletes a node. Without an explicit row lock at the top of
      # admin_destroy, B's destroy may race with A's move-update. Lock!
      # acquires SELECT FOR UPDATE so the second admin waits for the
      # first transaction to commit.
      it 'acquires a row lock on @review at the start of the action' do
        expect_any_instance_of(Review).to receive(:lock!).at_least(:once).and_call_original
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'lock test' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(Review.exists?(doomed_review.id)).to be(false)
      end

      # pre-destroy snapshot of the
      # entire reply tree captured into the Component-level audit's
      # audited_changes. For PII/legal hard-delete, the operator-facing
      # snapshot IS the legal record — not just reply_count integer.
      it 'captures destroyed_review_snapshots covering parent + every descendant' do
        grandchild = create(:review, :comment, comment: 'grandchild legal-record content',
                                               section: nil, user: adm_d_commenter, rule: rule,
                                               responding_to_review_id: reply_to_doomed.id)
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'snapshot test' }, as: :json
        expect(response).to have_http_status(:ok)

        component_audit = Audited::Audit.where(
          auditable_type: 'Component', action: 'admin_destroy_review'
        ).where('comment LIKE ?', '%snapshot test%').last
        expect(component_audit).to be_present

        # audited_changes is YAML-serialized with symbol keys preserved.
        # Snapshot rows themselves use string keys (per Review#snapshot_attributes).
        changes = component_audit.audited_changes
        snapshots = changes[:destroyed_review_snapshots]
        expect(snapshots).to be_an(Array)
        expect(snapshots.size).to eq(3) # parent + reply + grandchild

        ids = snapshots.pluck('id')
        expect(ids).to contain_exactly(doomed_review.id, reply_to_doomed.id, grandchild.id)

        # Each snapshot is a full hash with the audited + lifecycle columns
        parent_snap = snapshots.find { |s| s['id'] == doomed_review.id }
        expect(parent_snap['comment']).to eq('PII content')
        expect(parent_snap['user_id']).to eq(adm_d_commenter.id)
        expect(parent_snap['rule_id']).to eq(rule.id)
        expect(parent_snap['created_at']).to be_a(String) # ISO8601, not Time

        grandchild_snap = snapshots.find { |s| s['id'] == grandchild.id }
        expect(grandchild_snap['comment']).to eq('grandchild legal-record content')
        expect(grandchild_snap['responding_to_review_id']).to eq(reply_to_doomed.id)
      end
    end

    context 'as a non-admin author' do
      before { sign_in adm_d_author }

      it 'returns 403 and leaves the review intact' do
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: 'unauthorized' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(Review.exists?(doomed_review.id)).to be(true)
      end
    end
  end
end
