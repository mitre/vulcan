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

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig('toast', 'variant')).to eq('danger')
      expect(rule.reload.review_requestor_id).to be_nil
    end
  end

  describe 'PATCH /reviews/:id/triage' do
    let_it_be(:triager) { create(:user) }
    let_it_be(:commenter) { create(:user) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:other_component) { create(:component, project: other_project, based_on: srg) }

    # before_all (test_prof) runs once before any example in this describe;
    # using before(:each) here would race with let!(:comment), which has to
    # build a Review whose validate_project_permissions sees commenter as
    # a viewer of `project`.
    before_all do
      Membership.find_or_create_by!(user: triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let(:other_rule) { other_component.rules.first }
    let!(:comment) do
      Review.create!(action: 'comment', comment: 'check text issue', user: commenter,
                     rule: rule, section: 'check_content')
    end

    context 'as an author' do
      before { sign_in triager }

      it 'sets triage_status + audit fields and creates a response Review when text is supplied' do
        patch "/reviews/#{comment.id}/triage", params: {
          triage_status: 'concur_with_comment',
          response_comment: "Thanks — we'll adopt with stricter regex."
        }, as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.triage_status).to eq('concur_with_comment')
        expect(comment.triage_set_by_id).to eq(triager.id)
        expect(comment.triage_set_at).to be_within(5.seconds).of(Time.current)

        response_review = Review.find_by(responding_to_review_id: comment.id)
        expect(response_review).to be_present
        expect(response_review.action).to eq('comment')
        expect(response_review.section).to eq('check_content')
        expect(response_review.user_id).to eq(triager.id)
        expect(response_review.comment).to match(/stricter regex/)
      end

      it 'rejects triage_status non_concur without response_comment' do
        patch "/reviews/#{comment.id}/triage", params: {
          triage_status: 'non_concur'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/decline requires a response/i)
        expect(comment.reload.triage_status).to eq('pending')
      end

      it 'requires duplicate_of_review_id when triage_status is duplicate' do
        patch "/reviews/#{comment.id}/triage", params: {
          triage_status: 'duplicate'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/canonical comment/i)
      end

      it 'allows informational without response_comment + auto-sets adjudicated_at' do
        patch "/reviews/#{comment.id}/triage", params: {
          triage_status: 'informational'
        }, as: :json

        expect(response).to have_http_status(:ok)
        comment.reload
        expect(comment.triage_status).to eq('informational')
        expect(comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
      end

      it 'is idempotent on re-triage and audits each transition' do
        patch "/reviews/#{comment.id}/triage",
              params: { triage_status: 'concur', response_comment: 'first call' }, as: :json
        expect(comment.reload.triage_status).to eq('concur')

        patch "/reviews/#{comment.id}/triage",
              params: { triage_status: 'non_concur', response_comment: 'changed our mind' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(comment.reload.triage_status).to eq('non_concur')

        triage_audits = comment.audits.select { |a| a.audited_changes['triage_status'] }
        expect(triage_audits.size).to be >= 2
      end

      it 'rejects an unknown triage_status' do
        patch "/reviews/#{comment.id}/triage", params: { triage_status: 'whatever' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(comment.reload.triage_status).to eq('pending')
      end

      it 'returns 404 for a non-existent review id' do
        patch '/reviews/9999999/triage', params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'IDOR — author of project A cannot triage a Review in project B' do
      before { sign_in triager }

      let!(:other_comment) do
        outsider = create(:user)
        Membership.find_or_create_by!(user: outsider, membership: other_project) { |m| m.role = 'viewer' }
        Review.create!(action: 'comment', comment: 'in other project',
                       user: outsider, rule: other_rule)
      end

      it 'returns 403 with structured permission_denied body' do
        patch "/reviews/#{other_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to eq('permission_denied')
        expect(other_comment.reload.triage_status).to eq('pending')
      end
    end

    context 'as a viewer (not authorized to triage)' do
      before { sign_in commenter }

      it 'returns 403 and leaves the comment untouched' do
        patch "/reviews/#{comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(comment.reload.triage_status).to eq('pending')
      end
    end
  end

  describe 'PATCH /reviews/:id/adjudicate' do
    let_it_be(:adj_triager) { create(:user) }
    let_it_be(:adj_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: adj_triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: adj_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:triaged_comment) do
      c = Review.create!(action: 'comment', comment: 'check issue', user: adj_commenter,
                         rule: rule, section: 'check_content')
      c.update!(triage_status: 'concur_with_comment',
                triage_set_by_id: adj_triager.id, triage_set_at: Time.current)
      c
    end

    context 'as an author' do
      before { sign_in adj_triager }

      it 'sets adjudicated_at and adjudicated_by_id' do
        patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json

        expect(response).to have_http_status(:ok)
        triaged_comment.reload
        expect(triaged_comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
        expect(triaged_comment.adjudicated_by_id).to eq(adj_triager.id)
      end

      it 'creates a final response Review when resolution_comment is supplied' do
        expect do
          patch "/reviews/#{triaged_comment.id}/adjudicate",
                params: { resolution_comment: 'Updated rule in commit abc123' },
                as: :json
        end.to change(Review, :count).by(1)

        response_review = Review.find_by(responding_to_review_id: triaged_comment.id,
                                         comment: 'Updated rule in commit abc123')
        expect(response_review).to be_present
        expect(response_review.user_id).to eq(adj_triager.id)
        expect(response_review.section).to eq(triaged_comment.section)
      end

      it 'is idempotent on re-adjudicate (no-op, returns 200)' do
        patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
        original_at = triaged_comment.reload.adjudicated_at

        patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
        expect(response).to have_http_status(:ok)
        expect(triaged_comment.reload.adjudicated_at).to eq(original_at)
      end

      it 'rejects adjudicating a still-pending comment' do
        pending_comment = Review.create!(action: 'comment', comment: 'still pending',
                                         user: adj_commenter, rule: rule)
        patch "/reviews/#{pending_comment.id}/adjudicate", params: {}, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/triaged before/i)
        expect(pending_comment.reload.adjudicated_at).to be_nil
      end
    end

    context 'as a viewer' do
      before { sign_in adj_commenter }

      it 'returns 403' do
        patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # PATCH /reviews/:id/reopen — admins and authors can revert an adjudicated
  # comment back to "decided but not closed" state, allowing the triage
  # decision to be revised. Withdrawn comments (commenter-revoked) are NOT
  # re-openable by triagers — withdrawal is the commenter's prerogative.
  describe 'PATCH /reviews/:id/reopen' do
    let_it_be(:reopen_triager) { create(:user) }
    let_it_be(:reopen_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: reopen_triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: reopen_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    def adjudicated_comment(triage_status: 'concur')
      c = Review.create!(action: 'comment', comment: 'check issue', user: reopen_commenter,
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

      it 'rejects re-opening a non-adjudicated comment (nothing to revert)' do
        pending_comment = Review.create!(action: 'comment', comment: 'still pending',
                                         user: reopen_commenter, rule: rule)
        patch "/reviews/#{pending_comment.id}/reopen", as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects re-opening a withdrawn comment (commenter-revoked is locked from triagers)' do
        withdrawn = Review.create!(action: 'comment', comment: 'going back', user: reopen_commenter,
                                   rule: rule)
        withdrawn.update!(triage_status: 'withdrawn')

        patch "/reviews/#{withdrawn.id}/reopen", as: :json

        expect(response).to have_http_status(:unprocessable_entity)
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
      Review.create!(action: 'comment', comment: 'my idea', user: wd_owner, rule: rule)
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
        expect(response).to have_http_status(:unprocessable_entity)
        expect(my_comment.reload.triage_status).to eq('concur')
      end
    end
  end

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
      Review.create!(action: 'comment', comment: 'original text', user: edit_owner, rule: rule)
    end

    context 'as the original commenter while pending' do
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
        expect(response).to have_http_status(:unprocessable_entity)
        expect(my_comment.reload.comment).to eq('original text')
      end
    end
  end
end
