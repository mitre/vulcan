# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /projects/:id/comments' do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }
  let(:application_json) { 'application/json' }

  before do
    Rails.application.reload_routes!
    create(:membership, user: user, membership: project, role: 'admin')
    sign_in user
  end

  it 'redirects HTML requests to the triage page' do
    get "/projects/#{project.id}/comments"
    expect(response).to redirect_to("/projects/#{project.id}/triage")
  end

  it 'returns JSON for API requests' do
    rule = component.rules.first
    create(:review, :comment, comment: 'test comment', user: user, rule: rule)

    get "/projects/#{project.id}/comments",
        params: { triage_status: 'all' },
        headers: { 'Accept' => application_json }

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body).to have_key('rows')
    expect(body).to have_key('pagination')
  end

  it 'rejects requests for a non-existent project' do
    get '/projects/99999999/comments', headers: { 'Accept' => application_json }
    expect(response.status).to be >= 400
  end

  it 'sets Cache-Control: no-store' do
    get "/projects/#{project.id}/comments", headers: { 'Accept' => application_json }
    expect(response.headers['Cache-Control'].to_s).to match(/no-store/i)
  end
end
