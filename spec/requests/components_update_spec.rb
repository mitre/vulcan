# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component update' do
  include_context 'components request base setup'

  # ==========================================================================
  # REQUIREMENT: UpdateComponentDetailsModal must be able to update basic
  # component fields (name, description, version, etc.) WITHOUT sending
  # advanced_fields. The before_action filter should not require advanced_fields.
  # ==========================================================================
  describe 'PUT /components/:id' do
    context 'when updating basic fields without advanced_fields' do
      it 'updates name successfully' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'Updated Component Name'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.name).to eq('Updated Component Name')
      end

      it 'updates description successfully' do
        put "/components/#{component.id}", params: {
          component: {
            description: 'Updated description text'
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.description).to eq('Updated description text')
      end

      it 'updates multiple basic fields at once' do
        put "/components/#{component.id}", params: {
          component: {
            name: 'New Name',
            version: '2',
            release: '1',
            title: 'New Title',
            description: 'New description'
          }
        }

        expect(response).to have_http_status(:success)
        component.reload
        expect(component.name).to eq('New Name')
        expect(component.version.to_s).to eq('2')
        expect(component.release.to_s).to eq('1')
        expect(component.title).to eq('New Title')
        expect(component.description).to eq('New description')
      end
    end

    context 'when updating advanced_fields' do
      it 'allows admin to update advanced_fields' do
        put "/components/#{component.id}", params: {
          component: { advanced_fields: true }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.advanced_fields).to be(true)
      end
    end

    context 'as project viewer (not author)' do
      let(:viewer_user) { create(:user) }

      before do
        Membership.create!(user: viewer_user, membership: project, role: 'viewer')
        sign_in viewer_user
      end

      it 'rejects — update requires author' do
        put "/components/#{component.id}",
            params: { component: { name: 'Should Fail' } },
            headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as project author updating advanced_fields' do
      let(:author_user) { create(:user) }

      before do
        Membership.create!(user: author_user, membership: project, role: 'author')
        sign_in author_user
      end

      it 'rejects — advanced_fields requires admin' do
        put "/components/#{component.id}",
            params: { component: { advanced_fields: true } },
            headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        put "/components/#{component.id}",
            params: { component: { name: 'No Auth' } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
