# frozen_string_literal: true

require 'rails_helper'

# Project admin continuity at the membership endpoints: the last project
# admin cannot be removed (DELETE) or downgraded (PUT) — 422 with a toast
# naming the project. Removal/downgrade succeeds when another project
# admin remains.
RSpec.describe 'Memberships last admin' do
  let!(:site_admin) { create(:user, admin: true) }
  let(:project) { create(:project) }
  let(:sole_admin) { create(:user) }
  let!(:sole_admin_membership) do
    create(:membership, user: sole_admin, membership: project, role: 'admin')
  end

  let(:json_headers) { { 'Accept' => 'application/json' } }

  before do
    Rails.application.reload_routes!
    sign_in site_admin
  end

  describe 'DELETE /memberships/:id on the last project admin' do
    it 'returns 422 naming the project and keeps the membership' do
      expect do
        delete "/memberships/#{sole_admin_membership.id}", headers: json_headers
      end.not_to change(Membership, :count)

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Could not remove membership.')
      expect(body.dig('toast', 'message').join)
        .to include("Cannot remove the last admin of project '#{project.name}'")
    end
  end

  describe 'PUT /memberships/:id downgrading the last project admin' do
    it 'returns 422 and leaves the role unchanged' do
      put "/memberships/#{sole_admin_membership.id}",
          params: { membership: { role: 'author' } },
          headers: json_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = response.parsed_body
      expect(body.dig('toast', 'title')).to eq('Could not update membership.')
      expect(body.dig('toast', 'message').join)
        .to include("last admin of project '#{project.name}'")
      expect(sole_admin_membership.reload.role).to eq('admin')
    end
  end

  describe 'with a second project admin present' do
    let!(:second_admin_membership) do
      create(:membership, user: create(:user), membership: project, role: 'admin')
    end

    it 'allows removing one admin' do
      expect do
        delete "/memberships/#{sole_admin_membership.id}", headers: json_headers
      end.to change(Membership, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it 'allows downgrading one admin' do
      put "/memberships/#{sole_admin_membership.id}",
          params: { membership: { role: 'reviewer' } },
          headers: json_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(sole_admin_membership.reload.role).to eq('reviewer')
    end
  end
end
