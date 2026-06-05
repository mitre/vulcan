# frozen_string_literal: true

require 'rails_helper'

# PATCH /reviews/:id/reopen — admins and authors can revert an adjudicated
# comment back to "decided but not closed" state, allowing the triage
# decision to be revised. Withdrawn comments (commenter-revoked) are NOT
# re-openable by triagers — withdrawal is the commenter's prerogative.
RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

  describe 'PATCH /reviews/:id/reopen' do
    let_it_be(:reopen_triager) { create(:user) }
    let_it_be(:reopen_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: reopen_triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: reopen_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    def adjudicated_comment(triage_status: 'concur')
      c = create(:review, :comment, comment: 'check issue', user: reopen_commenter,
                                    rule: rule, section: 'check_content')
      c.update!(triage_status: triage_status,
                triage_set_by_id: reopen_triager.id,
                triage_set_at: Time.current,
                adjudicated_by_id: reopen_triager.id,
                adjudicated_at: Time.current)
      c
    end

    context 'as an author' do
      before { sign_in reopen_triager }

      it 'clears adjudicated_at and adjudicated_by_id and preserves triage_status' do
        comment = adjudicated_comment(triage_status: 'concur')
        patch "/reviews/#{comment.id}/reopen", as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.adjudicated_at).to be_nil
        expect(comment.adjudicated_by_id).to be_nil
        expect(comment.triage_status).to eq('concur') # decision retained for revision
      end

      it 'clears adjudicated_at for terminal status "duplicate" (does not re-adjudicate)' do
        survivor = create(:review, :comment, comment: 'survivor', section: nil,
                                             user: reopen_commenter, rule: rule)
        comment = adjudicated_comment(triage_status: 'concur')
        comment.update!(triage_status: 'duplicate', duplicate_of_review_id: survivor.id)
        patch "/reviews/#{comment.id}/reopen", as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.adjudicated_at).to be_nil
        expect(comment.triage_status).to eq('duplicate')
      end

      it 'clears adjudicated_at for terminal status "informational" (does not re-adjudicate)' do
        comment = adjudicated_comment(triage_status: 'informational')
        patch "/reviews/#{comment.id}/reopen", as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.adjudicated_at).to be_nil
        expect(comment.triage_status).to eq('informational')
      end

      it 'clears adjudicated_at for terminal status "addressed_by" (does not re-adjudicate)' do
        comment = adjudicated_comment(triage_status: 'concur')
        comment.update!(triage_status: 'addressed_by', addressed_by_rule_id: rule.id)
        patch "/reviews/#{comment.id}/reopen", as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.adjudicated_at).to be_nil
        expect(comment.triage_status).to eq('addressed_by')
      end

      it 'rejects re-opening a non-adjudicated comment (nothing to revert)' do
        pending_comment = create(:review, :comment, comment: 'still pending', section: nil,
                                                    user: reopen_commenter, rule: rule)
        patch "/reviews/#{pending_comment.id}/reopen", as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects re-opening a withdrawn comment (commenter-revoked is locked from triagers)' do
        withdrawn = create(:review, :comment, comment: 'going back', section: nil,
                                              user: reopen_commenter, rule: rule)
        withdrawn.update!(triage_status: 'withdrawn')

        patch "/reviews/#{withdrawn.id}/reopen", as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(withdrawn.reload.adjudicated_at).to be_present
      end

      it 'returns 404 for a non-existent review id' do
        patch '/reviews/9999999/reopen', as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'as a viewer (not authorized to triage)' do
      before { sign_in reopen_commenter }

      it 'returns 403 and leaves the comment adjudicated' do
        comment = adjudicated_comment(triage_status: 'concur')
        patch "/reviews/#{comment.id}/reopen", as: :json
        expect(response).to have_http_status(:forbidden)
        expect(comment.reload.adjudicated_at).to be_present
      end
    end
  end
end
