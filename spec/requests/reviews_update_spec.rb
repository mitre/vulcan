# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

  describe 'PUT /reviews/:id (commenter edit own pending comment)' do
    let_it_be(:edit_owner) { create(:user) }
    let_it_be(:edit_other) { create(:user) }
    let_it_be(:edit_author) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: edit_owner, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: edit_other, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: edit_author, membership: project) { |m| m.role = 'author' }
    end

    let!(:my_comment) do
      create(:review, :comment, comment: 'original text', section: nil, user: edit_owner, rule: rule)
    end

    context 'as the original commenter while pending' do
      include_context 'with auditing'
      before { sign_in edit_owner }

      it 'updates the comment text' do
        put "/reviews/#{my_comment.id}", params: { review: { comment: 'edited text' } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(my_comment.reload.comment).to eq('edited text')
      end

      it 'audits the edit (vulcan_audited captures the comment column)' do
        expect do
          put "/reviews/#{my_comment.id}", params: { review: { comment: 'edited' } }, as: :json
        end.to change(my_comment.audits, :count).by(1)
      end
    end

    context 'as a different user' do
      before { sign_in edit_other }

      it 'returns 403 and leaves the comment text unchanged' do
        put "/reviews/#{my_comment.id}", params: { review: { comment: 'sneaky' } }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(my_comment.reload.comment).to eq('original text')
      end
    end

    context 'after the comment has been triaged' do
      before do
        my_comment.update!(triage_status: 'concur',
                           triage_set_by_id: edit_author.id, triage_set_at: Time.current)
        sign_in edit_owner
      end

      it 'rejects edits with a 422' do
        put "/reviews/#{my_comment.id}", params: { review: { comment: 'too late' } }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(my_comment.reload.comment).to eq('original text')
      end
    end

    # same gap as withdraw above. A user removed
    # from the project could still edit their own pending comments because
    # :authorize_viewer_project was never wired into the update path.
    context 'as the commenter who was removed from the project' do
      before do
        Membership.where(user: edit_owner, membership: project).destroy_all
        sign_in edit_owner
      end

      it 'returns 403 and leaves the comment text unchanged' do
        put "/reviews/#{my_comment.id}", params: { review: { comment: 'sneaky edit' } }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(my_comment.reload.comment).to eq('original text')
      end
    end
  end
end
