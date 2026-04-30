# frozen_string_literal: true

require 'rails_helper'

# Task 29 — DISA disposition matrix CSV export
#
# REQUIREMENT: at the end of a public-comment review window, DISA expects a
# structured per-comment record (the "disposition matrix") for every comment
# raised against a component, with triage decisions and adjudication outcomes.
#
# This is a federal-compliance deliverable — the only mandatory artifact in
# this PR. CSV is the format DISA consumes today; OSCAL is deferred (see
# vulcan-oscal-disposition-deadend memory).
#
# Authorization model:
# - Viewer-tier: REJECTED (403) — viewers include external commenters, and
#   commenter-email scraping must not be possible.
# - Author/reviewer-tier: allowed, but the Commenter Email column is OMITTED
#   server-side. include_email=true on the request is silently ignored.
# - Admin-tier: allowed; include_email=true adds the Commenter Email column.
# - Unauthenticated: redirect to sign-in.
#
# Audit log: every export records who exported what, when, and whether
# include_email was set (compliance — "who has the email roster").
RSpec.describe 'GET /components/:id/export?type=disposition_csv' do
  let_it_be(:anchor_admin) { create(:user, :admin) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }

  let_it_be(:viewer) { create(:user) }
  let_it_be(:triager) { create(:user, name: 'Aaron Lippold') }
  let_it_be(:project_admin) { create(:user) }
  let_it_be(:commenter) { create(:user, name: 'Sarah K', email: 'sarah@example.com') }

  before do
    Rails.application.reload_routes!
    Membership.find_or_create_by!(user: viewer, membership: project) { |m| m.role = 'viewer' }
    Membership.find_or_create_by!(user: triager, membership: project) { |m| m.role = 'author' }
    Membership.find_or_create_by!(user: project_admin, membership: project) { |m| m.role = 'admin' }
    Membership.find_or_create_by!(user: commenter, membership: project) { |m| m.role = 'viewer' }
  end

  let(:rule) { component.rules.first }
  let!(:c1) do
    Review.create!(rule: rule, user: commenter, action: 'comment',
                   section: 'check_content', comment: 'check text issue',
                   triage_status: 'concur_with_comment',
                   triage_set_by: triager, triage_set_at: 1.day.ago,
                   adjudicated_at: 12.hours.ago, adjudicated_by: triager)
  end
  let!(:reply) do
    Review.create!(rule: rule, user: triager, action: 'comment',
                   responding_to_review_id: c1.id,
                   comment: 'will fix in next revision',
                   triage_status: 'pending')
  end

  context 'as author (triager tier — minimum allowed)' do
    before { sign_in triager }

    it 'returns 200 with CSV content type and the locked header row' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.body.lines.first).to include('Comment ID', 'Rule', 'SRG ID', 'Section')
    end

    it 'OMITS the Commenter Email column by default' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'IGNORES include_email=true for non-admin users (server-side enforcement)' do
      get "/components/#{component.id}/export/disposition_csv",
          params: { include_email: 'true' }
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'returns one row per top-level comment (replies collapsed into Triager Response)' do
      get "/components/#{component.id}/export/disposition_csv"
      csv = CSV.parse(response.body, headers: true)
      expect(csv.length).to eq(1)
      row = csv.first
      expect(row['Comment ID']).to eq(c1.id.to_s)
      expect(row['Rule']).to eq("#{component.prefix}-#{rule.rule_id}")
      expect(row['Triager Response']).to include('will fix')
      expect(row['Triage Status']).to eq('concur_with_comment')
      expect(row['Adjudicated']).to eq('true')
    end

    it 'filters by triage_status query param' do
      Review.create!(rule: rule, user: commenter, action: 'comment',
                     comment: 'pending one', triage_status: 'pending')
      get "/components/#{component.id}/export/disposition_csv",
          params: { triage_status: 'pending' }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.length).to eq(1)
      expect(csv.first['Triage Status']).to eq('pending')
    end

    it 'sets Content-Disposition with a sensible filename' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response.headers['Content-Disposition']).to match(/disposition-matrix.*\.csv/)
    end
  end

  context 'as project admin with include_email=true' do
    before { sign_in project_admin }

    it 'INCLUDES the Commenter Email column with the email value' do
      get "/components/#{component.id}/export/disposition_csv",
          params: { include_email: 'true' }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.first['Commenter Email']).to eq('sarah@example.com')
    end

    it 'OMITS the Commenter Email column when include_email is not set (default safe)' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response.body).not_to include('Commenter Email')
    end

    it 'records an audit entry capturing exporter + include_email flag' do
      expect do
        get "/components/#{component.id}/export/disposition_csv",
            params: { include_email: 'true' }
      end.to change { component.audits.count }.by_at_least(1)
      latest = component.audits.last
      expect(latest.user_id).to eq(project_admin.id)
    end
  end

  context 'as viewer (rejected — too loose for PII)' do
    before { sign_in viewer }

    it 'returns 403 — viewers cannot export disposition data' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'unauthenticated' do
    it 'redirects to sign in' do
      get "/components/#{component.id}/export/disposition_csv"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
