# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

  describe 'PATCH /reviews/:id/adjudicate' do
    let_it_be(:adj_triager) { create(:user) }
    let_it_be(:adj_commenter) { create(:user) }

    before_all do
      Membership.find_or_create_by!(user: adj_triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: adj_commenter, membership: project) { |m| m.role = 'viewer' }
    end

    let!(:triaged_comment) do
      c = create(:review, :comment, comment: 'check issue', user: adj_commenter,
                                    rule: rule, section: 'check_content')
      c.update!(triage_status: 'concur_with_comment',
                triage_set_by_id: adj_triager.id, triage_set_at: Time.current)
      c
    end

    context 'as an author' do
      before { sign_in adj_triager }

      it 'sets adjudicated_at and adjudicated_by_id' do
        before_call = Time.current.floor(6)
        patch "/reviews/#{triaged_comment.id}/adjudicate", params: {}, as: :json
        after_call = Time.current

        expect(response).to have_http_status(:ok)
        triaged_comment.reload
        expect(triaged_comment.adjudicated_at).to be_between(before_call, after_call)
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
        pending_comment = create(:review, :comment, comment: 'still pending', section: nil,
                                                    user: adj_commenter, rule: rule)
        patch "/reviews/#{pending_comment.id}/adjudicate", params: {}, as: :json

        expect(response).to have_http_status(:unprocessable_content)
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

  # The response comment must land on the parent's commentable — the
  # Rule-classed association returns nil for authored SrgRules, which left
  # the response with no commentable (422) before the fix.
  describe 'PATCH /reviews/:id/adjudicate response on an srg-kind parent' do
    let_it_be(:srg_author) { create(:user) }
    let_it_be(:srg_project) { create(:project) }
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: srg_project, document_type: 'srg', prefix: 'SRGX-00',
                                      name: 'Authored SRG adjudicate', title: 'Authored SRG adjudicate')
    end
    let_it_be(:authored_rule) { create(:srg_rule, :authored, component: srg_component, rule_id: '000001') }

    before_all do
      Membership.find_or_create_by!(user: srg_author, membership: srg_project) { |m| m.role = 'author' }
    end

    before { sign_in srg_author }

    it 'creates the response on the parent authored requirement' do
      parent = create(:review, :comment, :concur, user: srg_author, rule: nil, commentable: authored_rule,
                                                  comment: 'srg feedback', section: 'fixtext')

      patch "/reviews/#{parent.id}/adjudicate", params: { resolution_comment: 'Closing this out.' }, as: :json

      expect(response).to have_http_status(:ok)
      resp = Review.find_by!(responding_to_review_id: parent.id)
      expect(resp.commentable_type).to eq('BaseRule')
      expect(resp.commentable_id).to eq(authored_rule.id)
      expect(resp.rule_id).to eq(authored_rule.id)
    end
  end
end
