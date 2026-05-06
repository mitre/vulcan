# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reactions' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:other_viewer) { create(:user) }
  let_it_be(:outsider) { create(:user) }
  let(:rule) { component.rules.first }
  let(:comment_review) do
    Review.create!(action: 'comment', comment: 'a comment', user: viewer, rule: rule)
  end

  before do
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
    Membership.find_or_create_by!(user: other_viewer, membership: project) { |m| m.role = 'viewer' }
    Rails.application.reload_routes!
  end

  describe 'POST /reviews/:review_id/reactions' do
    context 'as an unauthenticated user' do
      it 'redirects to login or returns 401' do
        post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
      end
    end

    context 'as an outsider (no project membership)' do
      before { sign_in outsider }

      it 'returns 403 with structured permission_denied payload' do
        post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('permission_denied')
      end
    end

    context 'as a viewer' do
      before { sign_in viewer }

      it 'creates a new up reaction (happy path)' do
        expect do
          post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        end.to change(Reaction, :count).by(1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['reactions']).to eq('up' => 1, 'down' => 0, 'mine' => 'up')
      end

      it 'toggles off when the same user posts the same kind twice' do
        Reaction.create!(review: comment_review, user: viewer, kind: 'up')
        expect do
          post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        end.to change(Reaction, :count).by(-1)
        expect(response.parsed_body['reactions']).to eq('up' => 0, 'down' => 0, 'mine' => nil)
      end

      it 'switches kind atomically (up → down)' do
        Reaction.create!(review: comment_review, user: viewer, kind: 'up')
        expect do
          post "/reviews/#{comment_review.id}/reactions", params: { kind: 'down' }, as: :json
        end.not_to change(Reaction, :count)
        expect(response.parsed_body['reactions']).to eq('up' => 0, 'down' => 1, 'mine' => 'down')
      end

      it 'rejects an unknown kind with 422' do
        post "/reviews/#{comment_review.id}/reactions", params: { kind: 'meh' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/invalid/i)
      end

      it 'allows reacting to a reply (Decision 7)' do
        reply = Review.create!(action: 'comment', comment: 'reply', user: viewer, rule: rule,
                               responding_to_review_id: comment_review.id)
        expect do
          post "/reviews/#{reply.id}/reactions", params: { kind: 'up' }, as: :json
        end.to change(Reaction, :count).by(1)
        expect(response).to have_http_status(:ok)
      end

      it 'rejects reacting to a non-comment review with the structured 403' do
        non_comment = comment_review
        non_comment.update_columns(action: 'approve')
        post "/reviews/#{non_comment.id}/reactions", params: { kind: 'up' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('permission_denied')
      end

      it 'returns the soft 403 for a nonexistent review id' do
        post '/reviews/9999999/reactions', params: { kind: 'up' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body.dig('toast', 'message')).to match(/isn't available/i)
      end

      it 'rejects when the component is closed (comment_phase=closed)' do
        component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        expect do
          post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        end.not_to change(Reaction, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/finalized/i)
      end

      it 'uses the adjudicating closed message when closed_reason is adjudicating' do
        component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
        expect(response.parsed_body.dig('toast', 'message').join).to match(/adjudicat/i)
      end
    end
  end

  describe 'GET /reviews/:review_id/reactions' do
    before do
      sign_in viewer
      Reaction.create!(review: comment_review, user: viewer, kind: 'up')
      Reaction.create!(review: comment_review, user: other_viewer, kind: 'up')
      Reaction.create!(review: comment_review, user: anchor_admin, kind: 'down')
    end

    it 'returns reactor names grouped by kind' do
      get "/reviews/#{comment_review.id}/reactions", as: :json
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['up'].size).to eq(2)
      expect(body['down'].size).to eq(1)
    end

    it 'returns name only — never email or id (PII guard)' do
      get "/reviews/#{comment_review.id}/reactions", as: :json
      body = response.parsed_body
      (body['up'] + body['down']).each do |reactor|
        expect(reactor.keys).to eq(['name'])
      end
    end

    it 'still works on a closed component (Decision 3 — historical visibility)' do
      component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
      get "/reviews/#{comment_review.id}/reactions", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['up'].size).to eq(2)
    end

    it 'returns the soft 403 for a nonexistent review id' do
      get '/reviews/9999999/reactions', as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  # TOCTOU rescue path: in production two concurrent transactions can
  # both pass the lookup-then-create app-level validator and only the
  # unique index catches the loser via RecordNotUnique. RSpec
  # transactional fixtures + AR connection-pool quirks make multi-thread
  # tests flaky, so we exercise the rescue branch directly via a stub
  # that raises RecordNotUnique from create!.
  describe 'POST concurrent toggle (TOCTOU rescue path)' do
    before { sign_in viewer }

    it 'absorbs a RecordNotUnique collision and returns 2xx with the winner state' do
      winner = Reaction.create!(review: comment_review, user: viewer, kind: 'up')
      relation = instance_double(ActiveRecord::Relation)
      allow(Reaction).to receive(:lock).and_return(relation)
      allow(relation).to receive(:find_by)
        .with(review_id: comment_review.id, user_id: viewer.id)
        .and_return(nil)
      allow(Reaction).to receive(:create!)
        .and_raise(ActiveRecord::RecordNotUnique.new('unique-violation'))

      post "/reviews/#{comment_review.id}/reactions", params: { kind: 'up' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['reactions']).to eq('up' => 1, 'down' => 0, 'mine' => 'up')
      expect(Reaction.find_by(id: winner.id)).to be_present
    end
  end
end
