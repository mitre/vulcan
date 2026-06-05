# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

  describe 'PATCH /reviews/:id/withdraw' do
    let_it_be(:wd_owner) { create(:user) }
    let_it_be(:wd_other) { create(:user) }
    let_it_be(:wd_author) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: wd_owner, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: wd_other, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: wd_author, membership: project) { |m| m.role = 'author' }
    end

    let!(:my_comment) do
      create(:review, :comment, comment: 'my idea', section: nil, user: wd_owner, rule: rule)
    end

    context 'as the original commenter on a pending comment' do
      before { sign_in wd_owner }

      it 'sets triage_status=withdrawn and auto-sets adjudicated_at + adjudicated_by_id=self' do
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:ok)

        my_comment.reload
        expect(my_comment.triage_status).to eq('withdrawn')
        expect(my_comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
        expect(my_comment.adjudicated_by_id).to eq(wd_owner.id)
      end
    end

    context 'as a different user (not the original commenter)' do
      before { sign_in wd_other }

      it 'returns 403 and leaves the comment untouched' do
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:forbidden)
        expect(my_comment.reload.triage_status).to eq('pending')
      end
    end

    context 'when the comment has already been triaged' do
      before do
        my_comment.update!(triage_status: 'concur',
                           triage_set_by_id: wd_author.id, triage_set_at: Time.current)
        sign_in wd_owner
      end

      it 'rejects withdraw on a triaged comment with a 422' do
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(my_comment.reload.triage_status).to eq('concur')
      end
    end

    # policy: a user removed from the project
    # has no remaining authority on the project. They cannot withdraw their
    # own pending comments after leaving. The comment itself stays put
    # (project record stability); the actor just loses the ability to alter
    # it. Owner-equality alone (authorize_review_owner) is not enough — the
    # project membership gate must run first.
    context 'as the commenter who was removed from the project' do
      before do
        Membership.where(user: wd_owner, membership: project).destroy_all
        sign_in wd_owner
      end

      it 'returns 403 and leaves the comment untouched' do
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:forbidden)
        expect(my_comment.reload.triage_status).to eq('pending')
      end
    end
  end
end
