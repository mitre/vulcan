# frozen_string_literal: true

require 'rails_helper'

# comment_phase gates the public-comment workflow.
#
#   open                       — public comments accepted; triage allowed
#   closed (no reason)         — no NEW public comments; triage allowed
#   closed + adjudicating      — no NEW public comments; triage continues
#   closed + finalized         — frozen; no Review writes anywhere
#
# The controller honors the phase + closed_reason combination so the
# lifecycle has teeth.
RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

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

      [
        { comment_phase: 'closed', closed_reason: nil, label: 'closed (no reason)' },
        { comment_phase: 'closed', closed_reason: 'adjudicating', label: 'closed+adjudicating' },
        { comment_phase: 'closed', closed_reason: 'finalized', label: 'closed+finalized' }
      ].each do |closed_state|
        it "rejects posting when phase is #{closed_state[:label]}" do
          phase_component.update_columns(comment_phase: closed_state[:comment_phase],
                                         closed_reason: closed_state[:closed_reason])
          post "/rules/#{phase_rule.id}/reviews",
               params: { review: { action: 'comment', comment: 'no', component_id: phase_component.id } },
               as: :json
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('Comments are closed')
        end
      end

      it 'does not gate non-comment actions on phase (request_review remains author-only and unaffected)' do
        # request_review is author-tier so the viewer here would be denied
        # for OTHER reasons; the point is that the phase-gate check returns
        # before the role-gate so a viewer attempting request_review on a
        # closed component still gets an auth error, NOT the comments-closed error.
        phase_component.update_columns(comment_phase: 'closed', closed_reason: nil)
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'request_review', comment: 'try', component_id: phase_component.id } },
             as: :json
        expect(response.body).not_to include('Comments are closed')
      end
    end

    # Replies (responding_to_review_id present) are allowed when the
    # component is in a triaging-active phase (open OR closed+adjudicating)
    # so needs-clarification round-trips finish even after the public
    # comment window closes. closed+finalized still blocks everything.
    describe 'POST /rules/:rule_id/reviews — replies during closed phases' do
      let!(:parent_comment) do
        phase_component.update_columns(comment_phase: 'open', closed_reason: nil)
        create(:review, :comment, rule: phase_rule, user: phase_commenter,
                                  comment: 'parent', section: nil, triage_status: 'pending')
      end

      before { sign_in phase_viewer }

      it 'allows a reply during closed+adjudicating' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'reply during adjudication',
                                 component_id: phase_component.id,
                                 responding_to_review_id: parent_comment.id } },
             as: :json
        expect(response).to have_http_status(:success)
        expect(Review.last.responding_to_review_id).to eq(parent_comment.id)
      end

      it 'rejects a reply during closed+finalized' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'too late',
                                 component_id: phase_component.id,
                                 responding_to_review_id: parent_comment.id } },
             as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Comments are closed')
      end

      it 'rejects a new top-level comment during closed+adjudicating (gate still applies without responding_to_review_id)' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'sneaky new',
                                 component_id: phase_component.id } },
             as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Comments are closed')
      end

      it 'rejects a reply pointing at a non-comment review (defensive — guards against ID confusion)' do
        @phase_rule_under_review = phase_rule
        non_comment = create(:review, rule: phase_rule, user: phase_author,
                                      comment: 'requesting review', triage_status: 'pending')
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'sneaky',
                                 component_id: phase_component.id,
                                 responding_to_review_id: non_comment.id } },
             as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Comments are closed')
      end

      it 'rejects a reply pointing at a missing/deleted parent' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'orphan reply',
                                 component_id: phase_component.id,
                                 responding_to_review_id: 999_999 } },
             as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Comments are closed')
      end

      it 'rejects a reply whose parent is on a different component (cross-component bypass attempt)' do
        # Parent on a separate, OPEN component. We're posting to phase_rule
        # whose component is CLOSED. Should NOT bypass the closed gate just
        # because the smuggled responding_to_review_id resolves elsewhere.
        other_project = create(:project)
        other_component = create(:component, project: other_project, based_on: srg, comment_phase: 'open')
        other_rule = other_component.rules.first
        Membership.find_or_create_by!(user: phase_viewer, membership: other_project) { |m| m.role = 'viewer' }
        cross_parent = create(:review, :comment, rule: other_rule, user: phase_viewer,
                                                 comment: 'parent in other project', section: nil, triage_status: 'pending')

        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        post "/rules/#{phase_rule.id}/reviews",
             params: { review: { action: 'comment', comment: 'cross-bypass attempt',
                                 component_id: phase_component.id,
                                 responding_to_review_id: cross_parent.id } },
             as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Comments are closed')
      end
    end

    describe 'PATCH /reviews/:id/triage — closed+finalized freezes triage' do
      let!(:open_comment) do
        phase_component.update_columns(comment_phase: 'open')
        create(:review, :comment, rule: phase_rule, user: phase_commenter,
                                  comment: 'first', section: nil, triage_status: 'pending')
      end

      before { sign_in phase_author }

      it 'allows triage during open' do
        phase_component.update_columns(comment_phase: 'open')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:success)
      end

      it 'allows triage during closed+adjudicating' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'adjudicating')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:success)
      end

      it 'rejects triage when phase is closed+finalized' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        patch "/reviews/#{open_comment.id}/triage",
              params: { triage_status: 'concur' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PATCH /reviews/:id/adjudicate — closed+finalized freezes adjudication' do
      let!(:triaged_comment) do
        phase_component.update_columns(comment_phase: 'open')
        create(:review, :comment, :concur, rule: phase_rule, user: phase_commenter,
                                           comment: 'first', section: nil)
      end

      before { sign_in phase_author }

      it 'rejects adjudicate when phase is closed+finalized' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        patch "/reviews/#{triaged_comment.id}/adjudicate", as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PATCH /reviews/:id/withdraw — closed+finalized freezes withdraw' do
      let!(:my_comment) do
        phase_component.update_columns(comment_phase: 'open')
        create(:review, :comment, rule: phase_rule, user: phase_commenter,
                                  comment: 'mine', section: nil, triage_status: 'pending')
      end

      before { sign_in phase_commenter }

      it 'rejects withdraw when phase is closed+finalized' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        patch "/reviews/#{my_comment.id}/withdraw", as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('frozen')
      end
    end

    describe 'PUT /reviews/:id — closed+finalized freezes self-edit' do
      let!(:my_comment) do
        phase_component.update_columns(comment_phase: 'open')
        create(:review, :comment, rule: phase_rule, user: phase_commenter,
                                  comment: 'original', section: nil, triage_status: 'pending')
      end

      before { sign_in phase_commenter }

      it 'rejects edit when phase is closed+finalized' do
        phase_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
        put "/reviews/#{my_comment.id}",
            params: { review: { comment: 'edited' } }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('frozen')
      end
    end
  end
end
