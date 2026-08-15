# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Memberships' do
  let(:application_json) { 'application/json' }
  # Use let! to ensure admin_user is created first
  let!(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:project) { create(:project) }
  let!(:admin_membership) { create(:membership, user: admin_user, membership: project, role: 'admin') }
  let!(:target_membership) { create(:membership, user: regular_user, membership: project, role: 'viewer') }

  before do
    Rails.application.reload_routes!
  end

  describe 'DELETE /memberships/:id HTML format' do
    before { sign_in admin_user }

    it 'destroys the membership and redirects to project' do
      expect do
        delete "/memberships/#{target_membership.id}"
      end.to change(Membership, :count).by(-1)

      expect(response).to redirect_to(project_path(project))
      follow_redirect!
      expect(flash[:notice]).to eq('Successfully removed membership.')
    end
  end

  describe 'DELETE /memberships/:id JSON format' do
    before { sign_in admin_user }

    let(:json_headers) { { 'Accept' => application_json } }

    it 'destroys the membership and returns success JSON' do
      expect do
        delete "/memberships/#{target_membership.id}", headers: json_headers
      end.to change(Membership, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include(application_json)
      json = response.parsed_body
      expect(json['toast']).to be_a(Hash)
      expect(json['toast']['title']).to eq('Membership removed.')
    end

    it 'returns JSON error response on failure' do
      allow_any_instance_of(Membership).to receive(:destroy).and_return(false)
      allow_any_instance_of(Membership).to receive_message_chain(:errors, :full_messages).and_return(['Cannot delete'])

      delete "/memberships/#{target_membership.id}", headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include(application_json)
      json = response.parsed_body
      expect(json['toast']['title']).to include('Could not remove')
    end

    it 'still returns success when an in-app membership notification raises' do
      # safely_notify regression guard: a downstream notification failure
      # must NOT turn a successful destroy into a 500 — destroy already
      # committed; the user-facing operation succeeded.
      allow_any_instance_of(MembershipsController)
        .to receive(:send_membership_notification)
        .and_raise(StandardError, 'forced notification failure')

      delete "/memberships/#{target_membership.id}", headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['toast']).to be_a(Hash)
      expect(response.parsed_body['toast']['title']).to eq('Membership removed.')
      expect(Membership.find_by(id: target_membership.id)).to be_nil
    end

    # opt the success path into the canonical-toast-response
    # shared example so any future regression on this endpoint surfaces
    # alongside the controller-specific assertions above.
    context 'success-path toast shape' do
      before { delete "/memberships/#{target_membership.id}", headers: json_headers }

      it_behaves_like 'a canonical toast response'
    end
  end

  describe 'DELETE /memberships/:id with non-admin member' do
    before { sign_in regular_user }

    it 'raises authorization error' do
      expect do
        delete "/memberships/#{target_membership.id}"
      end.not_to change(Membership, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  # A non-member of a hidden project must not learn that a membership exists:
  # the denial is concealed as a 404 identical to a truly missing membership,
  # so membership ids cannot be probed.
  describe 'DELETE /memberships/:id concealment for a non-member of a hidden project' do
    let(:outsider) { create(:user, admin: false) }

    before { sign_in outsider }

    it 'answers a hidden-project membership identically to a nonexistent one (404 not_found)' do
      delete "/memberships/#{target_membership.id}", headers: { 'Accept' => application_json }
      concealed = { status: response.status, body: response.body }

      delete '/memberships/999999999', headers: { 'Accept' => application_json }
      missing = { status: response.status, body: response.body }

      expect(concealed[:status]).to eq(404)
      expect(response.parsed_body['type']).to eq('/docs/api/errors#not_found')
      expect(concealed).to eq(missing)
    end
  end
end
