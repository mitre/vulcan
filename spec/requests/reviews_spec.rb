# frozen_string_literal: true

require 'rails_helper'

# Coverage for POST /rules/:rule_id/reviews — exercises the create-side of
# ReviewsController. The lock_controls / lock_sections paths are covered by
# spec/requests/reviews_lock_controls_spec.rb.
RSpec.describe 'Reviews' do
  # Anchor admin: the first User row triggers the promote_first_user_to_admin
  # after_create hook. Without this anchor, whichever user happens to be
  # created first by a let_it_be block ends up admin=true, breaking permission
  # tests. Same convention as spec/requests/slack_notifications_spec.rb.
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }
  let(:rule) { component.rules.first }

  before { Rails.application.reload_routes! }

  describe 'POST /rules/:rule_id/reviews' do
    context 'as a project viewer' do
      let_it_be(:viewer) { create(:user) }

      before do
        create(:membership, user: viewer, membership: project, role: 'viewer')
        sign_in viewer
      end

      it 'allows posting a comment review' do
        expect do
          post "/rules/#{rule.id}/reviews", params: {
            review: { action: 'comment', comment: 'Question about this control.', component_id: component.id }
          }, as: :json
        end.to change(Review, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(Review.last).to have_attributes(action: 'comment', user: viewer, rule: rule)
      end

      it 'rejects an attempt to approve' do
        rule.update(review_requestor: create(:user))

        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'approve', comment: 'lgtm', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/Only admins and reviewers can approve/i)
      end

      it 'rejects an attempt to request_changes' do
        rule.update(review_requestor: create(:user))

        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_changes', comment: 'no', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects an attempt to request_review' do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_review', comment: 'please look', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join)
          .to match(/Only admins, reviewers, and authors can request a review/i)
        expect(rule.reload.review_requestor_id).to be_nil
      end

      it 'rejects an unknown action string with the inclusion validator error' do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'definitely_not_real', comment: 'sneaky', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/not a recognized review action/i)
      end
    end

    context 'as a project author' do
      let_it_be(:author) { create(:user) }

      before do
        create(:membership, user: author, membership: project, role: 'author')
        sign_in author
      end

      it 'allows posting a comment review' do
        expect do
          post "/rules/#{rule.id}/reviews", params: {
            review: { action: 'comment', comment: 'Author note.', component_id: component.id }
          }, as: :json
        end.to change(Review, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'allows requesting review' do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_review', comment: 'Please review.', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(rule.reload.review_requestor_id).to eq(author.id)
      end
    end

    context 'as a user with no project membership' do
      let_it_be(:outsider) { create(:user) }
      let_it_be(:project_admin_user) { create(:user) }

      before do
        # Set up at least one project admin so the structured 403 response has
        # something to populate the `admins` array with.
        create(:membership, user: project_admin_user, membership: project, role: 'admin')
        sign_in outsider
      end

      it 'returns a structured 403 with project admin contacts' do
        expect do
          post "/rules/#{rule.id}/reviews", params: {
            review: { action: 'comment', comment: 'I should not be here', component_id: component.id }
          }, as: :json
        end.not_to change(Review, :count)

        expect(response).to have_http_status(:forbidden)

        body = response.parsed_body
        expect(body['error']).to eq('permission_denied')
        expect(body['message']).to be_present
        expect(body['admins']).to be_an(Array)
        expect(body['admins']).to include(hash_including(
                                            'name' => project_admin_user.name,
                                            'email' => project_admin_user.email
                                          ))
        # Legacy toast shape kept for AlertMixin backwards compatibility
        expect(body.dig('toast', 'variant')).to eq('danger')
      end
    end

    context 'when not signed in' do
      it 'redirects to sign-in' do
        expect do
          post "/rules/#{rule.id}/reviews", params: {
            review: { action: 'comment', comment: 'unauth', component_id: component.id }
          }
        end.not_to change(Review, :count)

        expect(response).to have_http_status(:found)
      end
    end
  end
end
