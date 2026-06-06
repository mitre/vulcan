# frozen_string_literal: true

require 'rails_helper'

# PATCH /reviews/:id/section.
# Triager (author+) edits the `section` of an existing comment so misclassified
# comments can be retagged to the correct XCCDF section without rejecting the
# commenter or going out-of-band via the console. Audit-comment required.
RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

  describe 'PATCH /reviews/:id/section' do
    let_it_be(:sec_admin) { create(:user) }
    let_it_be(:sec_author) { create(:user) }
    let_it_be(:sec_viewer) { create(:user) }
    let_it_be(:sec_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: sec_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: sec_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: sec_viewer, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: sec_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:section_review) do
      create(:review, :comment, comment: 'misclassified', user: sec_commenter, rule: rule,
                                triage_status: 'pending', section: nil)
    end

    context 'as a triager (author tier — minimum allowed)' do
      before { sign_in sec_author }

      it 'updates the section and records an audit comment' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content',
                        audit_comment: 'tagging as Check after triager review' }, as: :json
        expect(response).to have_http_status(:ok)
        section_review.reload
        expect(section_review.section).to eq('check_content')
        expect(section_review.audits.last.comment).to include('tagging as Check')
      end

      it 'accepts null to clear the section back to general' do
        section_review.update!(section: 'check_content')
        patch "/reviews/#{section_review.id}/section",
              params: { section: nil, audit_comment: 'general after all' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(section_review.reload.section).to be_nil
      end

      it 'rejects an invalid section key' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'bogus_key', audit_comment: 'x' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(section_review.reload.section).to be_nil
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(section_review.reload.section).to be_nil
      end

      # the original test asserted only
      # `audits.count` didn't change, but Rails update!(same_value) triggers
      # no Dirty change so the audited gem writes nothing regardless of
      # whether the controller's explicit short-circuit is in place. That
      # makes the test tautological. Verify the controller actively detected
      # the no-change path by surfacing an `idempotent: true` flag in the
      # response body. A regression that removes the short-circuit would
      # also drop the flag, failing this assertion.
      it 'returns idempotent: true when section is unchanged (controller short-circuit)' do
        section_review.update!(section: 'check_content')
        before_count = section_review.audits.count
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: 'noop' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['idempotent']).to be(true)
        expect(section_review.reload.audits.count).to eq(before_count)
      end

      it 'does NOT include the idempotent flag when section actually changes' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'fixtext', audit_comment: 'real change' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).not_to have_key('idempotent')
      end

      it 'records the section change in the audit trail (vulcan_audited only must include section)' do
        expect do
          patch "/reviews/#{section_review.id}/section",
                params: { section: 'fixtext', audit_comment: 'audit-trail check' }, as: :json
        end.to change { section_review.reload.audits.count }.by_at_least(1)
        latest = section_review.audits.last
        expect(latest.audited_changes['section']).to eq([nil, 'fixtext'])
      end
    end

    context 'as a project admin' do
      before { sign_in sec_admin }

      it 'updates the section successfully' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: 'admin retag' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(section_review.reload.section).to eq('check_content')
      end
    end

    context 'as a viewer (rejected)' do
      before { sign_in sec_viewer }

      it 'returns 403 and leaves the section unchanged' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: 'unauthorized' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(section_review.reload.section).to be_nil
      end
    end

    context 'when not signed in' do
      it 'redirects to login (Devise behavior)' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: 'anon' }, as: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
      end
    end
  end
end
