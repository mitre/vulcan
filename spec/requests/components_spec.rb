# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'admin')
  end

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
        # Admin membership already set up in before block
        put "/components/#{component.id}", params: {
          component: {
            advanced_fields: true
          }
        }

        expect(response).to have_http_status(:success)
        expect(component.reload.advanced_fields).to be(true)
      end
    end
  end

  # ==========================================================================
  # REQUIREMENT: Components index should return optimized JSON with only
  # needed fields for table display. Should NOT include heavy fields.
  # ==========================================================================
  describe 'GET /components (Jbuilder optimization)' do
    let!(:released_component) do
      comp = create(:component, project: project, released: true)
      comp.reload
      comp
    end
    let!(:unreleased_component) { create(:component, project: project, released: false) }

    it_behaves_like 'jbuilder index', {
      path: '/components',
      factory: :component,
      required_fields: %w[id name version release prefix updated_at based_on_title based_on_version],
      excluded_fields: %w[rules reviews memberships histories metadata]
    }

    it 'only returns released components' do
      get '/components', headers: { 'Accept' => 'application/json' }

      json = response.parsed_body
      ids = json.pluck('id')

      expect(ids).to include(released_component.id)
      expect(ids).not_to include(unreleased_component.id)
    end
  end
end
