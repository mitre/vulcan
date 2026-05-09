# frozen_string_literal: true

require 'rails_helper'

# Coverage for POST /components/:component_id/reviews — component-level
# comments via polymorphic Review (issue #725). Mirrors the rule-scoped
# spec/requests/reviews_spec.rb create-side coverage.
RSpec.describe 'Component-level reviews' do
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }

  before { Rails.application.reload_routes! }

  describe 'POST /components/:component_id/reviews' do
    let_it_be(:viewer) { create(:user) }

    before do
      create(:membership, user: viewer, membership: project, role: 'viewer')
      sign_in viewer
    end

    it 'creates a component-scoped Review with commentable_type=Component' do
      expect do
        post "/components/#{component.id}/reviews", params: {
          review: { action: 'comment', comment: 'Top-level feedback on this component.' }
        }, as: :json
      end.to change(Review, :count).by(1)

      expect(response).to have_http_status(:ok)
      created = Review.last
      expect(created).to have_attributes(
        action: 'comment',
        user: viewer,
        rule_id: nil,
        commentable_type: 'Component',
        commentable_id: component.id,
        section: nil
      )
    end

    it 'rejects when the component is unauthorized for the user (non-member)' do
      sign_out viewer
      stranger = create(:user)
      sign_in stranger

      post "/components/#{component.id}/reviews", params: {
        review: { action: 'comment', comment: 'no access' }
      }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects new top-level comments when comment_phase is closed/finalized' do
      component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')

      post "/components/#{component.id}/reviews", params: {
        review: { action: 'comment', comment: 'too late' }
      }, as: :json
      expect(response.parsed_body['toast']['title']).to eq('Could not add comment.')
    end

    it 'allows replies during closed/adjudicating' do
      parent = Review.create!(commentable: component, user: viewer, action: 'comment', comment: 'parent')
      component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')

      expect do
        post "/components/#{component.id}/reviews", params: {
          review: { action: 'comment', comment: 'reply', responding_to_review_id: parent.id }
        }, as: :json
      end.to change(Review, :count).by(1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'reactions + reply-chain on component-scoped reviews' do
    let_it_be(:viewer) do
      u = create(:user)
      Membership.find_or_create_by!(user: u, membership: project) { |m| m.role = 'viewer' }
      u
    end
    let!(:parent) do
      Review.create!(commentable: component, user: viewer, action: 'comment', comment: 'parent')
    end

    before { sign_in viewer }

    it 'POST /reviews/:id/reactions on a component-scoped review succeeds (no 500 from nil rule)' do
      expect do
        post "/reviews/#{parent.id}/reactions", params: { kind: 'up' }, as: :json
      end.to change(Reaction, :count).by(1)
      expect(response).to have_http_status(:ok)
    end

    it 'GET /reviews/:id/responses on a component-scoped review returns the reply list' do
      Review.create!(commentable: component, user: viewer, action: 'comment',
                     comment: 'reply 1', responding_to_review_id: parent.id)
      get "/reviews/#{parent.id}/responses", as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['rows'].length).to eq(1)
    end
  end
end
