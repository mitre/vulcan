# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

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
      create(:review, :comment, comment: 'check text issue', user: commenter,
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

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/decline requires a response/i)
        expect(comment.reload.triage_status).to eq('pending')
      end

      it 'requires duplicate_of_review_id when triage_status is duplicate' do
        patch "/reviews/#{comment.id}/triage", params: {
          triage_status: 'duplicate'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/canonical comment/i)
      end

      # mark-as-duplicate decision flow. Most validators
      # already exist on the Review model (no_self_duplicate_reference,
      # duplicate_of_must_be_same_component, duplicate_status_requires_target).
      # The chained-duplicate guard is the new validator added in this task.
      describe 'duplicate marking' do # rubocop:disable RSpec/NestedGroups
        let_it_be(:rule_b) { component.rules.second }
        let!(:canonical) do
          create(:review, :comment, rule: rule, user: commenter,
                                    comment: 'canonical concern', section: nil, triage_status: 'pending')
        end
        let!(:dup_target_comment) do
          create(:review, :comment, rule: rule_b, user: commenter,
                                    comment: 'same concern, other rule', section: nil, triage_status: 'pending')
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

          expect(response).to have_http_status(:unprocessable_content)
          expect(dup_target_comment.reload.triage_status).to eq('pending')
        end

        it 'rejects cross-component canonical' do
          # anchor_admin has system-admin so they can create the foreign canonical
          # without the cross-scope validator tripping during test setup.
          other_canonical = create(:review, :comment, rule: other_rule, user: anchor_admin,
                                                      comment: 'foreign', section: nil, triage_status: 'pending')
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: other_canonical.id
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'rejects chained duplicates (canonical itself is a duplicate)' do
          chained = create(:review, :comment, rule: rule, user: commenter,
                                              comment: 'already a dup', section: nil, triage_status: 'duplicate',
                                              duplicate_of_review_id: canonical.id)
          patch "/reviews/#{dup_target_comment.id}/triage", params: {
            triage_status: 'duplicate',
            duplicate_of_review_id: chained.id
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.parsed_body.dig('toast', 'message').join)
            .to match(/ultimate canonical|another duplicate/i)
        end

        it 'allows re-marking to a different canonical' do
          dup_target_comment.update!(triage_status: 'duplicate', duplicate_of_review_id: canonical.id)
          new_canonical = create(:review, :comment, rule: rule, user: commenter,
                                                    comment: 'better canonical', section: nil, triage_status: 'pending')
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

      describe 'addressed_by marking' do # rubocop:disable RSpec/NestedGroups
        let_it_be(:parent_rule) { component.rules.second }

        it 'sets triage_status=addressed_by + addressed_by_rule_id + auto-adjudicates' do
          patch "/reviews/#{comment.id}/triage", params: {
            triage_status: 'addressed_by',
            addressed_by_rule_id: parent_rule.id
          }, as: :json

          expect(response).to have_http_status(:ok)
          comment.reload
          expect(comment.triage_status).to eq('addressed_by')
          expect(comment.addressed_by_rule_id).to eq(parent_rule.id)
          expect(comment.adjudicated_at).to be_within(5.seconds).of(Time.current)
        end

        it 'returns addressed_by_rule_id in the JSON response' do
          patch "/reviews/#{comment.id}/triage", params: {
            triage_status: 'addressed_by',
            addressed_by_rule_id: parent_rule.id
          }, as: :json

          expect(response).to have_http_status(:ok)
          body = response.parsed_body
          expect(body.dig('review', 'addressed_by_rule_id')).to eq(parent_rule.id)
        end

        it 'rejects addressed_by without addressed_by_rule_id' do
          patch "/reviews/#{comment.id}/triage", params: {
            triage_status: 'addressed_by'
          }, as: :json

          expect(response).to have_http_status(:unprocessable_content)
          expect(comment.reload.triage_status).to eq('pending')
        end
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
        expect(response).to have_http_status(:unprocessable_content)
        expect(comment.reload.triage_status).to eq('pending')
      end

      # REQUIREMENT: triage_status='pending' is the INITIAL state of every
      # comment. Submitting it to the triage endpoint isn't a triage decision
      # at all — accepting it would silently re-stamp triage_set_by_id and
      # triage_set_at on a still-pending comment, polluting the audit trail
      # with a fake "triaged by current_user" entry. Reject 422.
      it 'rejects triage_status=pending (no decision is being made)' do
        patch "/reviews/#{comment.id}/triage", params: { triage_status: 'pending' }, as: :json
        expect(response).to have_http_status(:unprocessable_content)
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
        create(:review, :comment, comment: 'in other project', section: nil,
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
end
