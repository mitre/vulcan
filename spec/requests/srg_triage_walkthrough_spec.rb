# frozen_string_literal: true

require 'rails_helper'

# The SRG triage-parity acceptance: the identical HTTP walkthrough —
# post a public comment on a requirement, triage it, adjudicate it,
# export the disposition matrix — runs against a STIG component and an
# SRG component through the SAME routes, controllers, and vocabulary.
# The shared example IS the parity assertion: one flow, zero kind
# branches, no SRG-specific adjudication path.
RSpec.describe 'SRG triage walkthrough' do
  # First user created — absorbs first-user-admin promotion so the
  # walkthrough personas keep their real roles.
  let_it_be(:anchor_admin) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:triager) do
    Membership.find_or_create_by!(user: create(:user, name: 'Walkthrough Triager'), membership: project) do |m|
      m.role = 'author'
    end.user
  end
  let_it_be(:commenter) do
    Membership.find_or_create_by!(user: create(:user, name: 'Walkthrough Commenter'), membership: project) do |m|
      m.role = 'viewer'
    end.user
  end

  before { Rails.application.reload_routes! }

  shared_examples 'full comment-to-disposition walkthrough' do
    it 'posts, triages, adjudicates, and exports the comment through the shared endpoints' do
      # 1. Public comment on the requirement (viewer tier).
      sign_in commenter
      post "/rules/#{requirement.id}/reviews", params: {
        review: { action: 'comment', comment: 'walkthrough: tighten the check text', section: 'check_content' }
      }, as: :json
      expect(response).to have_http_status(:ok)
      review = Review.find_by!(commentable_type: 'BaseRule', commentable_id: requirement.id,
                               comment: 'walkthrough: tighten the check text')
      expect(review.triage_status).to eq('pending')
      sign_out commenter

      # 2. Triage with the shared DISA vocabulary (author tier).
      sign_in triager
      patch "/reviews/#{review.id}/triage", params: {
        triage_status: 'concur_with_comment',
        response_comment: 'Adopting with a stricter check.'
      }, as: :json
      expect(response).to have_http_status(:ok)
      review.reload
      expect(review.triage_status).to eq('concur_with_comment')
      expect(review.triage_set_by_id).to eq(triager.id)

      # 3. Adjudicate.
      patch "/reviews/#{review.id}/adjudicate", as: :json
      expect(response).to have_http_status(:ok)
      review.reload
      expect(review.adjudicated_at).to be_present
      expect(review.adjudicated_by_id).to eq(triager.id)

      # 4. The disposition export carries the adjudicated comment —
      # asserted by PARSED CELL, not whole-body substring: the disposition
      # rows are not adjudication-gated, so substring checks would still
      # pass if adjudication never reached the CSV.
      get "/components/#{component.id}/export/disposition_csv"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')

      rows = CSV.parse(response.body, headers: true)
      row = rows.find { |r| r['Comment'] == 'walkthrough: tighten the check text' }
      expect(row).to be_present, 'walkthrough comment row missing from the disposition CSV'
      expect(row['Rule']).to include("#{component.prefix}-#{requirement.rule_id}")
      # Raw DISA status key — the export emits data keys, not labels.
      expect(row['Triage Status']).to eq('concur_with_comment')
      expect(row['Adjudicated']).to eq('true')
    end
  end

  describe 'STIG component (baseline)' do
    let_it_be(:srg) { create(:security_requirements_guide) }
    let_it_be(:component) do
      create(:component, project: project, based_on: srg, comment_phase: 'open')
    end
    let(:requirement) { component.rules.first }

    it_behaves_like 'full comment-to-disposition walkthrough'
  end

  describe 'SRG component (parity)' do
    let_it_be(:component) do
      create(:component, :skip_rules, project: project, document_type: 'srg', comment_phase: 'open')
    end
    let_it_be(:authored) { create(:srg_rule, :authored, component: component) }
    let(:requirement) { authored }

    it_behaves_like 'full comment-to-disposition walkthrough'
  end
end
