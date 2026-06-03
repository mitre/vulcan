# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Reviews + Reactions + Satisfactions endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:project) { create(:project, name: 'Reviews Contract Project') }
  let_it_be(:component) do
    create(:component, project: project, based_on: srg, name: 'Reviews Contract Comp',
                       prefix: 'RVCN-01', title: 'Reviews Contract Component',
                       comment_phase: 'open', comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 14.days.from_now)
  end
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end
  let_it_be(:rule) { component.rules.first || create(:rule, component: component) }
  let_it_be(:review) do
    create(:review, user: admin, rule: rule, action: 'comment',
                    comment: 'Reviews contract test comment', section: 'fixtext',
                    triage_status: 'pending')
  end

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── SECURITY HELPER: every review response must NOT have user_id ──

  def assert_review_no_user_id(body, key = 'review')
    review_data = body[key]
    return unless review_data

    assert_fields_absent review_data, :user_id
  end

  # ── PUT /reviews/:id (update comment text) ──

  describe 'PUT /reviews/:id (JSON)' do
    it 'returns ReviewWrapper with updated review and NO user_id' do
      put "/reviews/#{review.id}",
          params: { review: { comment: 'Updated contract test comment' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(review.id)
      expect(body['review']['comment']).to eq('Updated contract test comment')
      assert_fields_present body['review'], :id, :action, :comment, :triage_status, :rule_id, :reactions
      assert_review_no_user_id body
    end
  end

  # ── PATCH /reviews/:id/triage ──

  describe 'PATCH /reviews/:id/triage (JSON)' do
    it 'returns TriageResponse with review + optional response_review and NO user_id' do
      patch "/reviews/#{review.id}/triage",
            params: { triage_status: 'concur' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(review.id)
      expect(body['review']['triage_status']).to eq('concur')
      expect(body).to have_key('response_review')
      assert_review_no_user_id body
      assert_review_no_user_id body, 'response_review' if body['response_review']
    end
  end

  # ── PATCH /reviews/:id/reopen ──

  describe 'PATCH /reviews/:id/reopen (JSON)' do
    before do
      review.update!(triage_status: 'concur', triage_set_by_id: admin.id,
                     triage_set_at: Time.current, adjudicated_at: Time.current,
                     adjudicated_by_id: admin.id)
    end

    it 'returns ReviewWrapper with reopened review and NO user_id' do
      patch "/reviews/#{review.id}/reopen", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(review.id)
      assert_review_no_user_id body
    end
  end

  # ── PATCH /reviews/:id/withdraw ──

  describe 'PATCH /reviews/:id/withdraw (JSON)' do
    let_it_be(:withdrawable) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Withdrawable comment', triage_status: 'pending')
    end

    it 'returns ReviewWrapper with withdrawn review and NO user_id' do
      patch "/reviews/#{withdrawable.id}/withdraw", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(withdrawable.id)
      expect(body['review']['triage_status']).to eq('withdrawn')
      assert_review_no_user_id body
    end
  end

  # ── PATCH /reviews/:id/section ──

  describe 'PATCH /reviews/:id/section (JSON)' do
    it 'returns review with section changed and NO user_id' do
      patch "/reviews/#{review.id}/section",
            params: { section: 'vuln_discussion', audit_comment: 'Contract re-categorization' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(review.id)
      expect(body['review']['section']).to eq('vuln_discussion')
      assert_review_no_user_id body
    end
  end

  # ── PATCH /reviews/:id/admin_withdraw ──

  describe 'PATCH /reviews/:id/admin_withdraw (JSON)' do
    let_it_be(:admin_withdrawable) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Admin withdrawable', triage_status: 'pending')
    end

    it 'returns ReviewWrapper with admin-withdrawn review and NO user_id' do
      patch "/reviews/#{admin_withdrawable.id}/admin_withdraw",
            params: { audit_comment: 'Admin contract test withdraw' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(admin_withdrawable.id)
      expect(body['review']['triage_status']).to eq('withdrawn')
      assert_review_no_user_id body
    end
  end

  # ── PATCH /reviews/:id/admin_restore ──

  describe 'PATCH /reviews/:id/admin_restore (JSON)' do
    let_it_be(:restorable) do
      r = create(:review, user: admin, rule: rule, action: 'comment',
                          comment: 'Restorable comment', triage_status: 'withdrawn')
      r.update_columns(adjudicated_at: Time.current, adjudicated_by_id: admin.id)
      r
    end

    it 'returns ReviewWrapper with restored review and NO user_id' do
      patch "/reviews/#{restorable.id}/admin_restore",
            params: { audit_comment: 'Admin contract test restore' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(restorable.id)
      assert_review_no_user_id body
    end
  end

  # ── DELETE /reviews/:id/admin_destroy ──

  describe 'DELETE /reviews/:id/admin_destroy (JSON)' do
    let!(:destroyable) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Destroyable comment', triage_status: 'pending')
    end

    it 'returns AdminDestroyResponse with null review + destroyed_id and NO user_id' do
      delete "/reviews/#{destroyable.id}/admin_destroy",
             params: { audit_comment: 'Admin contract test destroy' },
             headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review, :destroyed_id
      expect(body['review']).to be_nil
      expect(body['destroyed_id']).to eq(destroyable.id)
      expect(body.keys).to contain_exactly('review', 'destroyed_id')
    end
  end

  # ── PATCH /reviews/:id/move_to_rule ──

  describe 'PATCH /reviews/:id/move_to_rule (JSON)' do
    let_it_be(:movable) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Movable comment', triage_status: 'pending')
    end
    let_it_be(:target_rule) do
      component.rules.where.not(id: rule.id).first ||
        component.rules.create!(rule_id: '999997', status: 'Not Yet Determined',
                                rule_severity: 'medium', rule_weight: '10.0',
                                version: rule.version, srg_rule: rule.srg_rule)
    end

    it 'returns ReviewWrapper with moved review and NO user_id' do
      patch "/reviews/#{movable.id}/move_to_rule",
            params: { rule_id: target_rule.id, audit_comment: 'Contract test move' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :review
      expect(body['review']['id']).to eq(movable.id)
      expect(body['review']['rule_id']).to eq(target_rule.id)
      assert_review_no_user_id body
    end
  end

  # ── GET /reviews/:id/responses ──

  describe 'GET /reviews/:id/responses (JSON)' do
    let_it_be(:reply) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Reply to contract test', responding_to_review_id: review.id,
                      section: review.section)
    end

    it 'returns { rows } with reply fields and reactions.mine' do
      get "/reviews/#{review.id}/responses", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows
      expect(body['rows']).to be_an(Array)
      expect(body['rows']).not_to be_empty
      expect(body.keys).to contain_exactly('rows')

      first_reply = body['rows'].first
      assert_fields_present first_reply, :id, :responding_to_review_id, :section,
                            :comment, :created_at, :commenter_display_name,
                            :commenter_email, :commenter_imported, :reactions
      assert_fields_present first_reply['reactions'], :up, :down, :mine
      assert_fields_absent first_reply, :user_id, :rule_id, :triage_status
    end
  end

  # ── GET /reviews/:id/reactions (detailed list) ──

  describe 'GET /reviews/:id/reactions (JSON)' do
    it 'returns ReactionsSummary with user name arrays' do
      get "/reviews/#{review.id}/reactions", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :up, :down
      expect(body['up']).to be_an(Array)
      expect(body['down']).to be_an(Array)
    end
  end

  # ── POST /reviews/:id/reactions (toggle) ──

  describe 'POST /reviews/:id/reactions (JSON)' do
    it 'returns ReactionToggleResponse with counts + mine' do
      post "/reviews/#{review.id}/reactions",
           params: { kind: 'up' },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :reactions
      assert_fields_present body['reactions'], :up, :down, :mine
      expect(body['reactions']['up']).to be_an(Integer)
      expect(body['reactions']['mine']).to eq('up')
    end
  end

  # ── PATCH /reviews/bulk_triage ──

  describe 'PATCH /reviews/bulk_triage (JSON)' do
    let_it_be(:bulk_review1) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Bulk triage 1', triage_status: 'pending')
    end
    let_it_be(:bulk_review2) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Bulk triage 2', triage_status: 'pending')
    end

    it 'returns BulkTriageResponse with reviews + response_reviews arrays' do
      patch '/reviews/bulk_triage',
            params: { review_ids: [bulk_review1.id, bulk_review2.id], triage_status: 'concur' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :reviews, :response_reviews
      expect(body['reviews']).to be_an(Array)
      expect(body['reviews'].length).to eq(2)
      expect(body['response_reviews']).to be_an(Array)
      body['reviews'].each do |r|
        expect(r['triage_status']).to eq('concur')
        assert_fields_absent r, :user_id
      end
    end
  end

  # ── PATCH /reviews/merge ──

  describe 'PATCH /reviews/merge (JSON)' do
    let_it_be(:merge_survivor) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Merge survivor', triage_status: 'pending')
    end
    let_it_be(:merge_duplicate) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Merge duplicate', triage_status: 'pending')
    end

    it 'returns MergeResponse with survivor + duplicates' do
      patch '/reviews/merge',
            params: { review_ids: [merge_survivor.id, merge_duplicate.id], survivor_id: merge_survivor.id },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :survivor, :duplicates
      expect(body['survivor']['id']).to eq(merge_survivor.id)
      expect(body['duplicates']).to be_an(Array)
      expect(body['duplicates'].length).to eq(1)
      expect(body['duplicates'].first['triage_status']).to eq('duplicate')
      expect(body['duplicates'].first['duplicate_of_review_id']).to eq(merge_survivor.id)
      assert_fields_absent body['survivor'], :user_id
    end
  end

  # ── POST /rule_satisfactions ──

  describe 'POST /rule_satisfactions (JSON)' do
    let_it_be(:other_rule) do
      component.rules.where.not(id: rule.id).first ||
        component.rules.create!(rule_id: '999998', status: 'Not Yet Determined',
                                rule_severity: 'medium', rule_weight: '10.0',
                                version: rule.version, srg_rule: rule.srg_rule)
    end

    it 'returns ToastResponse on success' do
      post '/rule_satisfactions',
           params: { rule_id: rule.id, satisfied_by_rule_id: other_rule.id },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('Satisfied-by')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end
end
