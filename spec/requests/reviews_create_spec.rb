# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

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
        expect(Review.where(rule: rule).order(:id).last).to have_attributes(action: 'comment', user: viewer, rule: rule)
      end

      # canonicalize create response toast.
      # Pre-fix the create endpoint returned `{toast: 'Successfully added
      # review.'}` (string), every other PR-717 endpoint returned
      # `{toast: {title:, message:, variant:}}` (object). Forced the
      # frontend AlertMixin to special-case string vs object. Now uniform.
      # opted into the canonical-toast-response shared
      # example so any future regression on this endpoint surfaces here.
      context 'success-path toast shape' do # rubocop:disable RSpec/NestedGroups
        before do
          post "/rules/#{rule.id}/reviews", params: {
            review: { action: 'comment', comment: 'shape check', component_id: component.id }
          }, as: :json
        end

        it 'returns 200 OK' do
          expect(response).to have_http_status(:ok)
        end

        it 'sets the variant to success' do
          expect(response.parsed_body.dig('toast', 'variant')).to eq('success')
        end

        it_behaves_like 'a canonical toast response'
      end

      it 'rejects an attempt to approve' do
        rule.update(review_requestor: create(:user))

        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'approve', comment: 'lgtm', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/Only admins and reviewers can approve/i)
      end

      it 'rejects an attempt to request_changes' do
        rule.update(review_requestor: create(:user))

        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_changes', comment: 'no', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'rejects an attempt to request_review' do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_review', comment: 'please look', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join)
          .to match(/Only admins, reviewers, and authors can request a review/i)
        expect(rule.reload.review_requestor_id).to be_nil
      end

      it 'rejects an unknown action string with the inclusion validator error' do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'definitely_not_real', comment: 'sneaky', component_id: component.id }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
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

  describe 'POST /rules/:rule_id/reviews — transaction integrity' do
    let_it_be(:author_user) { create(:user) }

    before do
      Membership.find_or_create_by!(user: author_user, membership: project) do |m|
        m.role = 'author'
      end
      sign_in author_user
    end

    # Forces the Review's INSERT to fail AFTER take_review_action's before_create
    # callback has already run rule.save!. _create_record is called inside the
    # save chain, after before_create. Without an explicit Review.transaction
    # in the controller, the rule mutation could leak past a failed insert.
    it 'rolls back rule mutation and returns 422 toast when the Review insert fails' do
      allow_any_instance_of(Review).to receive(:_create_record).and_raise(
        ActiveRecord::StatementInvalid.new('forced')
      )

      expect do
        post "/rules/#{rule.id}/reviews", params: {
          review: { action: 'request_review', comment: 'try', component_id: component.id }
        }, as: :json
      end.not_to change(Review, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'variant')).to eq('danger')
      expect(rule.reload.review_requestor_id).to be_nil
    end
  end

  describe 'soft redirect — comments on satisfied-by children' do
    let_it_be(:viewer) { create(:user) }
    let(:parent_rule) { component.rules.first }
    let(:child_rule) { component.rules.second }

    before do
      create(:membership, user: viewer, membership: project, role: 'viewer')
      child_rule.satisfied_by << parent_rule
      sign_in viewer
    end

    it 'redirects comment to parent rule when child is satisfied-by' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'This check is vendor-specific', section: 'fixtext' },
           as: :json

      expect(response).to have_http_status(:ok)
      review = Review.where(rule: parent_rule).order(:id).last
      expect(review.rule_id).to eq(parent_rule.id)
      expect(review.commentable_id).to eq(parent_rule.id)
    end

    it 'sets original_commentable_id to the child rule' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'Vendor concern', section: 'fixtext' },
           as: :json

      review = Review.where(rule: parent_rule).order(:id).last
      expect(review.original_commentable_id).to eq(child_rule.id)
    end

    it 'prefixes comment with [Re: prefix-child_rule_id]' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'Vendor concern', section: 'fixtext' },
           as: :json

      review = Review.where(rule: parent_rule).order(:id).last
      expect(review.comment).to start_with("[Re: #{component.prefix}-#{child_rule.rule_id}]")
      expect(review.comment).to include('Vendor concern')
    end

    it 'does NOT redirect when rule has no satisfied-by parent' do
      standalone = component.rules.where.not(id: [parent_rule.id, child_rule.id]).first
      post "/rules/#{standalone.id}/reviews",
           params: { action: 'comment', comment: 'Normal comment', section: 'fixtext' },
           as: :json

      expect(response).to have_http_status(:ok)
      review = Review.where(rule: standalone).order(:id).last
      expect(review.rule_id).to eq(standalone.id)
      expect(review.original_commentable_id).to be_nil
      expect(review.comment).to eq('Normal comment')
    end
  end
end
