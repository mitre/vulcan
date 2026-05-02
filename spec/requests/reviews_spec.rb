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
  # PR #717: comment posting requires comment_phase = 'open'. Most tests in
  # this file exercise the comment workflow; default the shared component
  # to open so they don't fail the new phase gate. Tests that need a
  # different phase set it explicitly via update_columns.
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }
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

      # PR #717 Task 24 — mark-as-duplicate decision flow. Most validators
      # already exist on the Review model (no_self_duplicate_reference,
      # duplicate_of_must_be_same_component, duplicate_status_requires_target).
      # The chained-duplicate guard is the new validator added in this task.
      describe 'duplicate marking' do # rubocop:disable RSpec/NestedGroups
        let_it_be(:rule_b) { component.rules.second }
        let!(:canonical) do
          Review.create!(rule: rule, user: commenter, action: 'comment',
                         comment: 'canonical concern', triage_status: 'pending')
        end
        let!(:dup_target_comment) do
          Review.create!(rule: rule_b, user: commenter, action: 'comment',
                         comment: 'same concern, other rule', triage_status: 'pending')
        end

        it 'sets triage_status=duplicate + duplicate_of_review_id when valid' do
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: canonical.id
          }, as: :json

          expect(response).to have_http_status(:ok)
          dup_target_comment.reload
          expect(dup_target_comment.triage_status).to eq('duplicate')
          expect(dup_target_comment.duplicate_of_review_id).to eq(canonical.id)
          expect(dup_target_comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
        end

        it 'rejects self-reference (the existing no_self_duplicate_reference validator)' do
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: dup_target_comment.id
          }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(dup_target_comment.reload.triage_status).to eq('pending')
        end

        it 'rejects cross-component canonical' do
          # anchor_admin has system-admin so they can create the foreign canonical
          # without the cross-scope validator tripping during test setup.
          other_canonical = Review.create!(rule: other_rule, user: anchor_admin, action: 'comment',
                                           comment: 'foreign', triage_status: 'pending')
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: other_canonical.id
          }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'rejects chained duplicates (canonical itself is a duplicate)' do
          chained = Review.create!(rule: rule, user: commenter, action: 'comment',
                                   comment: 'already a dup', triage_status: 'duplicate',
                                   duplicate_of_review_id: canonical.id)
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: chained.id
          }, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body.dig('toast', 'message').join)
            .to match(/ultimate canonical|another duplicate/i)
        end

        it 'allows re-marking to a different canonical' do
          dup_target_comment.update!(triage_status: 'duplicate', duplicate_of_review_id: canonical.id)
          new_canonical = Review.create!(rule: rule, user: commenter, action: 'comment',
                                         comment: 'better canonical', triage_status: 'pending')
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: new_canonical.id
          }, as: :json

          expect(response).to have_http_status(:ok)
          expect(dup_target_comment.reload.duplicate_of_review_id).to eq(new_canonical.id)
        end
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

      # REQUIREMENT: triage_status='pending' is the INITIAL state of every
      # comment. Submitting it to the triage endpoint isn't a triage decision
      # at all — accepting it would silently re-stamp triage_set_by_id and
      # triage_set_at on a still-pending comment, polluting the audit trail
      # with a fake "triaged by current_user" entry. Reject 422.
      it 'rejects triage_status=pending (no decision is being made)' do
        patch "/reviews/#{comment.id}/triage", params: { triage_status: 'pending' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        comment.reload
        expect(comment.triage_set_by_id).to be_nil
        expect(comment.triage_set_at).to be_nil
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

    # PR-717 review remediation .6 — policy: a user removed from the project
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

    # PR-717 review remediation .6 — same gap as withdraw above. A user removed
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

  # PR #717: comment_phase gates the public-comment workflow.
  #
  #   draft       — no public comments accepted
  #   open        — public comments accepted; triage allowed
  #   adjudication— no NEW public comments; triage continues
  #   final       — frozen; no Review writes anywhere
  #
  # The phase column was previously informational only — the controller
  # honors it now so the lifecycle has teeth.
  describe 'comment_phase enforcement' do
    let_it_be(:phase_seed_admin) { create(:user, admin: true) }
    let_it_be(:phase_project) { create(:project) }
    let_it_be(:phase_component) { create(:component, project: phase_project, based_on: srg) }
    let(:phase_rule) { phase_component.rules.first }

    let_it_be(:phase_viewer) { create(:user, admin: false) }
    let_it_be(:phase_author) { create(:user, admin: false) }
    let_it_be(:phase_commenter) { create(:user, admin: false) }

    before do
      Membership.find_or_create_by!(user: phase_viewer, membership: phase_project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: phase_author, membership: phase_project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: phase_commenter, membership: phase_project) { |m| m.role = 'viewer' }
    end

    describe 'POST /rules/:rule_id/reviews — public-comment posting' do
      before { sign_in phase_viewer }

      it 'allows posting when phase is open' do
        phase_component.update_columns(comment_phase: 'open')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'hello', component_id: phase_component.id } },
             as: :json
        expect(response).to have_http_status(:success)
      end

      %w[draft adjudication final].each do |closed_phase|
        it "rejects posting when phase is #{closed_phase}" do
          phase_component.update_columns(comment_phase: closed_phase)
          post "/rules/#{phase_rule.id}/reviews",
               params: { review: { action: 'comment', comment: 'no', component_id: phase_component.id } },
               as: :json
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include('Comments are closed')
        end
      end

      it 'does not gate non-comment actions on phase (request_review remains author-only and unaffected)' do
        # request_review is author-tier so the viewer here would be denied
        # for OTHER reasons; the point is that the phase-gate check returns
        # before the role-gate so a viewer/draft request_review still gets
        # an auth error, NOT the comments-closed error.
        phase_component.update_columns(comment_phase: 'draft')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'request_review', comment: 'try', component_id: phase_component.id } },
             as: :json
        expect(response.body).not_to include('Comments are closed')
      end
    end

    describe 'PATCH /reviews/:id/triage — final freezes triage' do
      let!(:open_comment) do
        phase_component.update_columns(comment_phase: 'open')
        Review.create!(rule: phase_rule, user: phase_commenter, action: 'comment',
                       comment: 'first', triage_status: 'pending')
      end

      before { sign_in phase_author }

      it 'allows triage during open' do
        phase_component.update_columns(comment_phase: 'open')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:success)
      end

      it 'allows triage during adjudication' do
        phase_component.update_columns(comment_phase: 'adjudication')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:success)
      end

      it 'rejects triage when phase is final' do
        phase_component.update_columns(comment_phase: 'final')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PATCH /reviews/:id/adjudicate — final freezes adjudication' do
      let!(:triaged_comment) do
        phase_component.update_columns(comment_phase: 'open')
        Review.create!(rule: phase_rule, user: phase_commenter, action: 'comment',
                       comment: 'first', triage_status: 'concur')
      end

      before { sign_in phase_author }

      it 'rejects adjudicate when phase is final' do
        phase_component.update_columns(comment_phase: 'final')
        patch "/reviews/#{triaged_comment.id}/adjudicate", as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PATCH /reviews/:id/withdraw — final freezes withdraw' do
      let!(:my_comment) do
        phase_component.update_columns(comment_phase: 'open')
        Review.create!(rule: phase_rule, user: phase_commenter, action: 'comment',
                       comment: 'mine', triage_status: 'pending')
      end

      before { sign_in phase_commenter }

      it 'rejects withdraw when phase is final' do
        phase_component.update_columns(comment_phase: 'final')
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PUT /reviews/:id — final freezes self-edit' do
      let!(:my_comment) do
        phase_component.update_columns(comment_phase: 'open')
        Review.create!(rule: phase_rule, user: phase_commenter, action: 'comment',
                       comment: 'original', triage_status: 'pending')
      end

      before { sign_in phase_commenter }

      it 'rejects edit when phase is final' do
        phase_component.update_columns(comment_phase: 'final')
        put "/reviews/#{my_comment.id}",
            params: { review: { comment: 'edited' } }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('frozen')
      end
    end
  end

  # PR-717 Task 25 — admin actions on a comment.
  # Force-withdraw lets a project admin override the commenter's intent
  # (spam, PII, policy violations, withdrawn-account cleanup). Audit
  # comment is required so the audit trail captures the
  # documented reason for the override.
  # Restore is the inverse — undo a force-withdraw (or any prior
  # adjudication) so the comment can be re-triaged. Same admin gate +
  # audit comment requirement.
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
      Review.create!(action: 'comment', comment: 'spam content', user: adm_commenter, rule: rule)
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
        expect(response).to have_http_status(:unprocessable_entity)
      end

      # PR-717 review remediation .16 — defense-in-depth length cap.
      # 4096 chars is the AUDIT_COMMENT_MAX_LENGTH constant on the controller.
      it 'accepts a 4096-char audit_comment' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'x' * 4096 }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'rejects a 4097-char audit_comment with 422' do
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'x' * 4097 }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
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

      it 'is allowed even when the component is in the final (frozen) phase' do
        component.update_columns(comment_phase: 'final')
        patch "/reviews/#{target_review.id}/admin_withdraw",
              params: { audit_comment: 'PII cleanup post-window' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(target_review.reload.triage_status).to eq('withdrawn')
      ensure
        component.update_columns(comment_phase: 'open')
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
      r = Review.create!(action: 'comment', comment: 'something', user: adm_r_commenter, rule: rule)
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
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects restoring a non-adjudicated comment (nothing to restore from)' do
        pending_review = Review.create!(action: 'comment', comment: 'still pending',
                                        user: adm_r_commenter, rule: rule)
        patch "/reviews/#{pending_review.id}/admin_restore",
              params: { audit_comment: 'no-op attempt' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
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

  # PR-717 Task 25b — DELETE /reviews/:id/admin_destroy.
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
      Review.create!(action: 'comment', comment: 'PII content', user: adm_d_commenter, rule: rule)
    end
    let!(:reply_to_doomed) do
      Review.create!(action: 'comment', comment: 'reply text', user: adm_d_author, rule: rule,
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

      it 'rejects when audit_comment is blank' do
        delete "/reviews/#{doomed_review.id}/admin_destroy",
               params: { audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
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

      # PR-717 review remediation .4 step 3 — FK swap regression test.
      # With FK on_delete: :restrict on responding_to_review_id, Rails
      # `dependent: :destroy` MUST walk the reply tree children-first
      # (recursively) so the parent delete doesn't violate the FK. This
      # test exercises a 3-level chain (parent → child → grandchild) AND
      # asserts every destroy event ends up sharing one request_uuid with
      # the operator's Component-level admin_destroy_review audit row —
      # the request_uuid correlation primitive AuditEventBundle uses for
      # forensic reconstruction.
      it 'cascades parent + child + grandchild via Rails callbacks; all events share one request_uuid' do
        grandchild = Review.create!(
          action: 'comment', comment: 'grandchild', user: adm_d_commenter, rule: rule,
          responding_to_review_id: reply_to_doomed.id
        )
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

      # PR-717 review remediation .4 F1 — FK semantics. Constraint must
      # be on_delete: :restrict so Rails owns the cascade (callbacks +
      # audited destroy events fire); FK is a safety net against bypass.
      it 'has FK responding_to_review_id with on_delete: :restrict' do
        fk = ActiveRecord::Base.connection.foreign_keys('reviews').find do |k|
          k.column == 'responding_to_review_id'
        end
        expect(fk).to be_present
        expect(fk.on_delete).to eq(:restrict)
      end

      # PR-717 review remediation .4 F3 — pre-destroy snapshot of the
      # entire reply tree captured into the Component-level audit's
      # audited_changes. For PII/legal hard-delete, the operator-facing
      # snapshot IS the legal record — not just reply_count integer.
      it 'captures destroyed_review_snapshots covering parent + every descendant' do
        grandchild = Review.create!(
          action: 'comment', comment: 'grandchild legal-record content',
          user: adm_d_commenter, rule: rule,
          responding_to_review_id: reply_to_doomed.id
        )
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

  # PR-717 Task 26 — PATCH /reviews/:id/move_to_rule.
  # Admin reassigns a misplaced comment (and atomically, all its replies)
  # to a different rule in the same component. Audit-comment required.
  # Walks parent-first so the responding_to_must_be_same_rule validator
  # sees the parent already at the target when each child moves.
  describe 'PATCH /reviews/:id/move_to_rule' do
    let_it_be(:mtr_admin) { create(:user) }
    let_it_be(:mtr_author) { create(:user) }
    let_it_be(:mtr_commenter) { create(:user) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:other_component) { create(:component, project: other_project, based_on: srg) }

    before_all do
      Membership.find_or_create_by!(user: mtr_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: mtr_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: mtr_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let(:rule_a) { component.rules.first }
    let(:rule_b) { component.rules.second }
    let(:rule_other_component) { other_component.rules.first }

    let!(:parent_review) do
      Review.create!(action: 'comment', comment: 'misplaced concern', user: mtr_commenter, rule: rule_a,
                     triage_status: 'pending')
    end
    let!(:reply_review) do
      Review.create!(action: 'comment', comment: 'thanks for raising', user: mtr_author, rule: rule_a,
                     triage_status: 'pending', responding_to_review_id: parent_review.id)
    end
    # PR-717 review remediation .11 — reply-of-reply, exercises depth>=2 in
    # move_review_subtree!. Without this, a regression that only descended
    # one level (e.g. responses.first&.update! instead of recursion) would
    # pass the original test.
    let!(:nested_reply_review) do
      Review.create!(action: 'comment', comment: 'follow-up to the reply', user: mtr_commenter, rule: rule_a,
                     triage_status: 'pending', responding_to_review_id: reply_review.id)
    end

    context 'as project admin' do
      before { sign_in mtr_admin }

      it 'reassigns the parent review and ALL replies (including reply-of-reply) to the target rule' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'belongs on rule B' }, as: :json
        expect(response).to have_http_status(:ok)
        expect(parent_review.reload.rule_id).to eq(rule_b.id)
        expect(reply_review.reload.rule_id).to eq(rule_b.id)
        expect(nested_reply_review.reload.rule_id).to eq(rule_b.id)
      end

      it 'rejects when target rule is in a different component' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_other_component.id, audit_comment: 'cross-component attempt' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parent_review.reload.rule_id).to eq(rule_a.id)
        # PR-717 review remediation .5 — toast variant must be a valid Bootstrap-Vue
        # value (success/warning/danger/info). The original code shipped
        # 'unprocessable_entity' which renders an unstyled toast.
        expect(response.parsed_body.dig('toast', 'variant')).to eq('warning')
      end

      it 'rejects when target rule is the same as the source rule' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_a.id, audit_comment: 'no-op' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'rejects when target rule does not exist' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: 999_999, audit_comment: 'nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'preserves triage_status and adjudication on move' do
        parent_review.update!(triage_status: 'concur',
                              adjudicated_at: 1.day.ago,
                              adjudicated_by_id: mtr_author.id)
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'reassigning' }, as: :json
        expect(response).to have_http_status(:ok)

        parent_review.reload
        expect(parent_review.rule_id).to eq(rule_b.id)
        expect(parent_review.triage_status).to eq('concur')
        expect(parent_review.adjudicated_at).to be_present
      end

      it 'records the rule_id change in the audit trail (vulcan_audited only must include rule_id)' do
        expect do
          patch "/reviews/#{parent_review.id}/move_to_rule",
                params: { rule_id: rule_b.id, audit_comment: 'audit-trail check' }, as: :json
        end.to change { parent_review.reload.audits.count }.by_at_least(1)
        latest = parent_review.audits.last
        expect(latest.audited_changes['rule_id']).to eq([rule_a.id, rule_b.id])
      end
    end

    context 'as a non-admin author' do
      before { sign_in mtr_author }

      it 'returns 403 and leaves the rule_id unchanged' do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'unauthorized' }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(parent_review.reload.rule_id).to eq(rule_a.id)
      end
    end
  end

  # PR-717 Task 30 — PATCH /reviews/:id/section.
  # Triager (author+) edits the `section` of an existing comment so misclassified
  # comments can be retagged to the correct XCCDF section without rejecting the
  # commenter or going out-of-band via the console. Audit-comment required.
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
      Review.create!(action: 'comment', comment: 'misclassified', user: sec_commenter, rule: rule,
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
        expect(response).to have_http_status(:unprocessable_entity)
        expect(section_review.reload.section).to be_nil
      end

      it 'rejects when audit_comment is blank' do
        patch "/reviews/#{section_review.id}/section",
              params: { section: 'check_content', audit_comment: '' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(section_review.reload.section).to be_nil
      end

      # PR-717 review remediation .12 — the original test asserted only
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
