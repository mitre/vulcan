# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Components' do
  before do
    Rails.application.reload_routes!
  end

  let(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:project) { create(:project) }

  describe 'GET /components (index)' do
    # The index action returns released components only
    # JSON format for API, HTML for page render
    let!(:released_component1) { create(:released_component, name: 'ReleasedComponentOne') }
    let!(:released_component2) { create(:released_component, name: 'ReleasedComponentTwo') }
    let!(:draft_component) { create(:component, name: 'DraftComponentHidden', released: false) }

    context 'when authenticated' do
      before { sign_in regular_user }

      it 'returns successful response for JSON' do
        get '/components', as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'includes released components in JSON response' do
        get '/components', as: :json
        json = response.parsed_body
        names = json.map { |c| c['name'] }
        expect(names).to include('ReleasedComponentOne')
        expect(names).to include('ReleasedComponentTwo')
      end

      it 'excludes draft components from public index' do
        get '/components', as: :json
        json = response.parsed_body
        names = json.map { |c| c['name'] }
        # Draft component should NOT appear in the released list
        expect(names).not_to include('DraftComponentHidden')
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        get '/components'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /components/:id (show)' do
    context 'with released component' do
      let(:released_component) { create(:released_component) }

      context 'when authenticated as any user' do
        before { sign_in regular_user }

        it 'allows access to released component' do
          get "/components/#{released_component.id}", headers: { 'Accept' => 'application/json' }
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when not authenticated' do
        it 'redirects to login' do
          get "/components/#{released_component.id}"
          expect(response).to redirect_to(new_user_session_path)
        end
      end
    end

    context 'with draft component' do
      let(:draft_component) { create(:component, released: false, project: project) }
      let(:project_member) { create(:user) }

      before do
        # Add project_member to the project
        create(:membership, user: project_member, membership: project)
      end

      context 'when authenticated as project member' do
        before { sign_in project_member }

        it 'allows access to draft component' do
          get "/components/#{draft_component.id}", headers: { 'Accept' => 'application/json' }
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when authenticated as non-member' do
        before { sign_in regular_user }

        it 'denies access to draft component' do
          get "/components/#{draft_component.id}", headers: { 'Accept' => 'application/json' }
          # Non-members can't view unreleased components - controller may return various error codes
          expect(response.status).to be >= 400
        end
      end
    end
  end

  describe 'DELETE /components/:id' do
    let(:component) { create(:component, project: project) }
    let(:project_admin) { create(:user) }

    before do
      # Make project_admin an admin of the project
      create(:membership, user: project_admin, membership: project, role: 'admin')
    end

    context 'when authenticated as project admin' do
      before { sign_in project_admin }

      it 'destroys the component' do
        component_id = component.id

        expect do
          delete "/components/#{component_id}", as: :json
        end.to change(Component, :count).by(-1)

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['toast']).to include('Successfully removed component')
      end
    end

    context 'when authenticated as regular user (non-admin of project)' do
      before { sign_in regular_user }

      it 'denies access' do
        component_id = component.id

        # Non-admin user cannot delete - should return forbidden (authenticated but not authorized)
        delete "/components/#{component_id}", as: :json

        expect(response).to have_http_status(:forbidden)
        # The component should still exist
        expect(Component.find_by(id: component_id)).to be_present
      end
    end

    context 'when authenticated as system admin' do
      before { sign_in admin_user }

      it 'allows system admin to destroy any component' do
        component_id = component.id

        expect do
          delete "/components/#{component_id}", as: :json
        end.to change(Component, :count).by(-1)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'released vs draft components (public/admin contract)' do
    let!(:released1) { create(:released_component, name: 'Public Component 1') }
    let!(:released2) { create(:released_component, name: 'Public Component 2') }
    let!(:draft1) { create(:component, name: 'Private Draft 1', released: false) }
    let!(:draft2) { create(:component, name: 'Private Draft 2', released: false) }

    context 'public index (released only)' do
      before { sign_in regular_user }

      it 'returns only released components for public view' do
        get '/components', as: :json

        expect(response).to have_http_status(:ok)
        # The index action only returns released: true
        json = response.parsed_body
        names = json.map { |c| c['name'] }
        expect(names).to include('Public Component 1')
        expect(names).to include('Public Component 2')
        expect(names).not_to include('Private Draft 1')
        expect(names).not_to include('Private Draft 2')
      end
    end

    context 'admin access to all components' do
      before { sign_in admin_user }

      it 'admin can access draft components by ID' do
        get "/components/#{draft1.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['name']).to eq('Private Draft 1')
      end

      it 'admin can access released components by ID' do
        get "/components/#{released1.id}", headers: { 'Accept' => 'application/json' }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['name']).to eq('Public Component 1')
      end
    end
  end
end
