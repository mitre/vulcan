# frozen_string_literal: true

require 'rails_helper'

# Project-aggregate DISA disposition matrix CSV export. Mirrors the
# per-component endpoint at spec/requests/components_disposition_matrix_export_spec.rb
# — viewer-tier rejected, author-tier allowed without email, admin-tier may opt
# in to include_email=true. CSV row-shape concerns are tested directly on the
# generator in spec/lib/disposition_matrix_export_spec.rb (the
# `.generate_for_project` describe block).
RSpec.describe 'GET /projects/:id/export/disposition_csv' do
  let_it_be(:anchor_admin) { create(:user, :admin) }
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component_a) { create(:component, project: project, based_on: srg, comment_phase: 'open') }

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

  let!(:c1) do
    Review.create!(rule: component_a.rules.first, user: commenter, action: 'comment',
                   section: 'check_content', comment: 'check text issue on a',
                   triage_status: 'pending')
  end

  let!(:component_b) do
    c = create(:component, project: project, based_on: srg, prefix: 'XYZW-99', name: 'Second component')
    Review.create!(rule: c.rules.first, user: commenter, action: 'comment',
                   comment: 'check text issue on b', triage_status: 'pending')
    c
  end

  context 'as author (triager tier — minimum allowed)' do
    before { sign_in triager }

    it 'returns 200 with text/csv content type' do
      get "/projects/#{project.id}/export/disposition_csv"
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
    end

    it 'sets Content-Disposition with a project-scoped filename' do
      get "/projects/#{project.id}/export/disposition_csv"
      expect(response.headers['Content-Disposition']).to match(/#{project.name}-disposition-matrix-\d{4}-\d{2}-\d{2}\.csv/)
    end

    it 'includes a leading Component column' do
      get "/projects/#{project.id}/export/disposition_csv"
      first_row = response.body.lines.first
      expect(first_row).to start_with('Component,')
    end

    it 'unions rows from every component in the project' do
      get "/projects/#{project.id}/export/disposition_csv"
      out = CSV.parse(response.body, headers: true)
      components_in_output = out.pluck('Component').uniq
      expect(components_in_output.size).to eq(2)
    end

    it 'OMITS the Commenter Email column for non-admin' do
      get "/projects/#{project.id}/export/disposition_csv"
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'IGNORES include_email=true for non-admin (server-side enforcement)' do
      get "/projects/#{project.id}/export/disposition_csv", params: { include_email: 'true' }
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'forwards triage_status filter through to all components' do
      Review.create!(rule: component_a.rules.first, user: commenter, action: 'comment',
                     comment: 'concurred', triage_status: 'concur',
                     triage_set_by: triager, triage_set_at: 1.hour.ago)
      get "/projects/#{project.id}/export/disposition_csv", params: { triage_status: 'pending' }
      out = CSV.parse(response.body, headers: true)
      expect(out.pluck('Triage Status').uniq).to eq(['pending'])
    end
  end

  context 'as project admin' do
    before { sign_in project_admin }

    it 'opt-in include_email=true adds Commenter Email column' do
      get "/projects/#{project.id}/export/disposition_csv", params: { include_email: 'true' }
      expect(response.body).to include('Commenter Email')
      expect(response.body).to include('sarah@example.com')
    end

    it 'records a project audit entry capturing exporter' do
      expect do
        get "/projects/#{project.id}/export/disposition_csv", params: { include_email: 'true' }
      end.to change { project.audits.count }.by_at_least(1)
      latest = project.audits.last
      expect(latest.user_id).to eq(project_admin.id)
    end
  end

  context 'as viewer (rejected — PII gate)' do
    before { sign_in viewer }

    it 'returns 403' do
      get "/projects/#{project.id}/export/disposition_csv"
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'unauthenticated' do
    it 'redirects to sign in' do
      get "/projects/#{project.id}/export/disposition_csv"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
