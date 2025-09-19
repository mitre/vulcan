# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Format Handling Across Controllers', type: :request do
  # Regression tests to ensure all controllers properly handle HTML vs JSON format requests
  # This prevents the FormMixin JSON header vs redirect_to mismatch issues

  include_context 'format handling test setup'

  describe 'ProjectsController#create' do
    let(:valid_params) { { project: { name: 'Test Project', description: 'Test Description', visibility: 'discoverable' } } }

    context 'HTML format request' do
      it 'redirects to created project on success' do
        post '/projects', params: valid_params

        expect(response).to have_http_status(:redirect)
        created_project = Project.find_by(name: 'Test Project')
        expect(response).to redirect_to(project_path(created_project))
      end

      it 'redirects to new action on failure' do
        post '/projects', params: { project: { name: '' } } # Invalid

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_project_path)
      end
    end

    context 'JSON format request' do
      let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

      it 'returns redirect_url in JSON on success' do
        post '/projects', params: valid_params.to_json, headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['redirect_url']).to be_present
        expect(json_response['toast']).to eq('Successfully created project')
      end

      it 'returns error JSON on failure' do
        post '/projects', params: { project: { name: '' } }.to_json, headers: json_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['toast']['variant']).to eq('danger')
      end
    end
  end

  describe 'UsersController#update' do
    let(:target_user) { create(:user, admin: false) }
    let(:valid_params) { { user: { admin: true } } }

    context 'HTML format request' do
      it 'redirects to users index on success' do
        put "/users/#{target_user.id}", params: valid_params

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(users_path)
      end
    end

    context 'JSON format request' do
      let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

      it 'returns toast JSON on success' do
        put "/users/#{target_user.id}", params: valid_params.to_json, headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['toast']).to eq('Successfully updated user')
      end
    end
  end

  describe 'MembershipsController#update' do
    let(:valid_params) { { membership: { role: 'admin' } } }

    context 'HTML format request' do
      it 'redirects to membership object on success' do
        put "/memberships/#{membership.id}", params: valid_params

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(project_path(project))
      end
    end

    context 'JSON format request' do
      let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

      it 'returns toast JSON on success' do
        put "/memberships/#{membership.id}", params: valid_params.to_json, headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['toast']).to eq('Successfully updated membership')
      end
    end
  end

  describe 'SecurityRequirementsGuidesController#destroy' do
    context 'HTML format request' do
      it 'redirects to index on success' do
        delete "/srgs/#{srg.id}"

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(srgs_path)
      end
    end

    context 'JSON format request' do
      let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

      it 'returns toast JSON on success' do
        delete "/srgs/#{srg.id}", headers: json_headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['toast']).to eq('Successfully removed SRG')
      end
    end
  end

  describe 'FormMixin + AlertMixin pattern verification' do
    # Ensure components using FormMixin + AlertMixin still work correctly

    context 'when both mixins are used together' do
      it 'properly handles JSON responses with toast messages' do
        # Test a controller that should return JSON (like project updates)
        put "/projects/#{project.id}",
            params: { project: { name: 'Updated Name' } }.to_json,
            headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        json_response = response.parsed_body
        expect(json_response['toast']).to be_present
      end
    end
  end

  describe 'regression prevention' do
    it 'ensures all affected controllers handle both HTML and JSON formats' do
      test_cases = [
        {
          name: 'ProjectsController#create',
          method: :post,
          path: '/projects',
          params: { project: { name: 'Test Project', description: 'Test Description', visibility: 'discoverable' } }
        },
        {
          name: 'UsersController#update',
          method: :put,
          path: "/users/#{admin_user.id}",
          params: { user: { admin: true } }
        },
        {
          name: 'MembershipsController#update',
          method: :put,
          path: "/memberships/#{membership.id}",
          params: { membership: { role: 'admin' } }
        }
      ]

      test_cases.each do |test_case|
        # Test HTML format
        send(test_case[:method], test_case[:path], params: test_case[:params])
        expect(response).to have_http_status(:redirect), "#{test_case[:method]} #{test_case[:path]} should redirect for HTML"

        # Test JSON format
        json_headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
        send(test_case[:method], test_case[:path], params: test_case[:params].to_json, headers: json_headers)
        expect(response.content_type).to include('application/json'), "#{test_case[:method]} #{test_case[:path]} should return JSON"
        expect([200, 201]).to include(response.status), "#{test_case[:name]} should succeed for JSON"
      end
    end

    it 'SecurityRequirementsGuidesController handles format correctly' do
      # Test SRG deletion separately since it has different data requirements
      test_srg = create(:security_requirements_guide)

      # Test HTML format
      delete "/srgs/#{test_srg.id}"
      expect(response).to have_http_status(:redirect), 'SRG deletion should redirect for HTML'

      # Create fresh SRG for JSON test (since first one was deleted)
      test_srg_second = create(:security_requirements_guide)

      # Test JSON format
      json_headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
      delete "/srgs/#{test_srg_second.id}", headers: json_headers
      expect(response.content_type).to include('application/json'), 'SRG deletion should return JSON'
      expect(response.status).to eq(200), 'SRG deletion should succeed for JSON'
    end
  end
end
