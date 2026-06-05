# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews base setup'

  # Task 33: reply-chain reader. Auth mirrors the parent component's
  # released-vs-member gate (released → any logged-in user; unreleased
  # → project member). Replies returned chronologically (oldest-first)
  # to match RuleReviews's nested-reply ordering.
  describe 'GET /reviews/:id/responses' do
    let_it_be(:rr_member) { create(:user) }
    let_it_be(:rr_outsider) { create(:user) }
    let_it_be(:rr_unreleased_component) { create(:component, project: project, based_on: srg, comment_phase: 'open', released: false) }
    let_it_be(:rr_released_component) { create(:component, project: project, based_on: srg, comment_phase: 'open', released: true) }

    let_it_be(:rr_unreleased_parent) do
      Membership.find_or_create_by!(user: rr_member, membership: project) { |m| m.role = 'viewer' }
      create(:review, :comment, comment: 'parent', section: nil, user: rr_member,
                                rule: rr_unreleased_component.rules.first)
    end

    let_it_be(:rr_released_parent) do
      create(:review, :comment, comment: 'parent on released', section: nil, user: rr_member,
                                rule: rr_released_component.rules.first)
    end

    before do
      create(:review, :comment, comment: 'first reply', section: nil, user: rr_member,
                                rule: rr_unreleased_parent.rule, responding_to_review_id: rr_unreleased_parent.id,
                                created_at: 1.minute.ago)
      create(:review, :comment, comment: 'second reply', section: nil, user: rr_member,
                                rule: rr_unreleased_parent.rule, responding_to_review_id: rr_unreleased_parent.id)
    end

    context 'on an unreleased component' do
      it 'returns the reply chain for a project member' do
        sign_in rr_member
        get "/reviews/#{rr_unreleased_parent.id}/responses", as: :json
        expect(response).to have_http_status(:ok)
        rows = response.parsed_body['rows']
        expect(rows.size).to eq(2)
        expect(rows.pluck('comment')).to eq(['first reply', 'second reply'])
      end

      it 'rejects a non-member' do
        sign_in rr_outsider
        get "/reviews/#{rr_unreleased_parent.id}/responses", as: :json
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects an unauthenticated request' do
        get "/reviews/#{rr_unreleased_parent.id}/responses", as: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
      end
    end

    context 'on a released component' do
      # Released components downgrade visibility to any logged-in user
      # (mirrors ComponentsController#authorize_component_access). This is
      # the public-comment-window behavior — a non-member can read so they
      # can decide whether to comment.
      it 'returns the reply chain for any logged-in user (non-member)' do
        sign_in rr_outsider
        get "/reviews/#{rr_released_parent.id}/responses", as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['rows']).to be_an(Array)
      end

      it 'rejects an unauthenticated request' do
        get "/reviews/#{rr_released_parent.id}/responses", as: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
      end
    end

    it 'returns 404 when the review does not exist' do
      sign_in rr_member
      get '/reviews/999999/responses', as: :json
      expect(response).to have_http_status(:not_found)
    end

    # PII guard: replies returned via this endpoint must not leak the
    # raw imported_email column when only that column is populated.
    it 'redacts commenter_display_name when only commenter_imported_email is set' do
      reply = rr_unreleased_parent.responses.first
      reply.update_columns(user_id: nil, commenter_imported_name: nil,
                           commenter_imported_email: 'leak@example.com')
      sign_in rr_member
      get "/reviews/#{rr_unreleased_parent.id}/responses", as: :json
      row = response.parsed_body['rows'].find { |r| r['id'] == reply.id }
      expect(row['commenter_display_name']).to eq('(imported commenter)')
      expect(row['commenter_imported']).to be(true)
      expect(response.body).not_to include('leak@example.com')
    end

    it 'includes reactions {up, down, mine} on each reply row' do
      reply = rr_unreleased_parent.responses.first
      Reaction.create!(review: reply, user: rr_member, kind: 'up')
      sign_in rr_member
      get "/reviews/#{rr_unreleased_parent.id}/responses", as: :json
      row = response.parsed_body['rows'].find { |r| r['id'] == reply.id }
      expect(row['reactions']).to eq('up' => 1, 'down' => 0, 'mine' => 'up')
    end
  end

  # Task 33: defense-in-depth — replies must be rejected when comment_phase
  # is closed. Today the existing reject_if_comments_closed filter applies
  # to action='comment' reviews regardless of responding_to_review_id, so
  # this is documenting+locking that behavior.
  describe 'POST /rules/:rule_id/reviews — closed-window reply rejection' do
    let_it_be(:closed_member) { create(:user) }
    let_it_be(:closed_component) do
      create(:component, project: project, based_on: srg, comment_phase: 'open')
    end
    let_it_be(:closed_parent) do
      Membership.find_or_create_by!(user: closed_member, membership: project) { |m| m.role = 'viewer' }
      create(:review, :comment, comment: 'parent', section: nil, user: closed_member,
                                rule: closed_component.rules.first)
    end

    before do
      closed_component.update_columns(comment_phase: 'closed', closed_reason: 'finalized')
      sign_in closed_member
    end

    it 'rejects a reply post when the component is closed for comments' do
      expect do
        post "/rules/#{closed_component.rules.first.id}/reviews", params: {
          review: { action: 'comment', comment: 'late reply',
                    component_id: closed_component.id,
                    responding_to_review_id: closed_parent.id }
        }, as: :json
      end.not_to change(Review, :count)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/closed/i)
    end
  end
end
