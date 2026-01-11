# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::FindReplace' do
  before do
    Rails.application.reload_routes!
    create(:membership, membership: project, user: user, role: 'author')
  end

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:project) { create(:project) }
  let(:srg) { create(:security_requirements_guide) }
  let(:component) { create(:component, project: project, based_on: srg) }

  # Create rules with various content for testing
  let!(:rule1) do
    create(:rule, component: component, rule_id: 'SV-001',
                  title: 'Configure sshd service',
                  fixtext: 'Edit /etc/ssh/sshd_config and set PermitRootLogin no. Restart sshd service.',
                  vendor_comments: 'The sshd daemon must be properly configured.')
  end

  let!(:rule2) do
    create(:rule, component: component, rule_id: 'SV-002',
                  title: 'Configure SSH key authentication',
                  fixtext: 'Configure sshd to use key-based authentication only.',
                  vendor_comments: nil)
  end

  # Set up user access

  describe 'POST /api/components/:component_id/find_replace/find' do
    let(:find_path) { "/api/components/#{component.id}/find_replace/find" }

    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        post find_path, params: { search: 'sshd' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated without access' do
      before { sign_in other_user }

      it 'denies access' do
        post find_path, params: { search: 'sshd' }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated with access' do
      before { sign_in user }

      it 'returns matches for valid search' do
        post find_path, params: { search: 'sshd' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['total_rules']).to eq(2)
        expect(json['total_matches']).to be >= 5
        expect(json['matches']).to be_an(Array)
      end

      it 'returns match instances with positions and context' do
        post find_path, params: { search: 'sshd' }

        json = response.parsed_body
        rule1_match = json['matches'].find { |m| m['rule_id'] == rule1.id }

        expect(rule1_match['rule_identifier']).to eq('SV-001')
        expect(rule1_match['instances']).to be_an(Array)

        first_field = rule1_match['instances'].first
        expect(first_field['field']).to be_present
        expect(first_field['instances'].first).to include('index', 'length', 'text', 'context')
      end

      it 'respects field filtering' do
        post find_path, params: { search: 'sshd', fields: ['title'] }

        json = response.parsed_body
        expect(json['total_rules']).to eq(1) # Only rule1 has 'sshd' in title
      end

      it 'respects case sensitivity' do
        post find_path, params: { search: 'SSHD', case_sensitive: true }

        json = response.parsed_body
        expect(json['total_matches']).to eq(0) # No uppercase SSHD in content
      end

      it 'returns empty for short queries' do
        post find_path, params: { search: 'a' }

        json = response.parsed_body
        expect(json['total_matches']).to eq(0)
      end

      it 'requires search parameter' do
        post find_path, params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/components/:component_id/find_replace/replace_instance' do
    let(:replace_instance_path) { "/api/components/#{component.id}/find_replace/replace_instance" }

    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'openssh'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as viewer (read-only)' do
      before do
        Membership.find_by(user: user, membership: project).update!(role: 'viewer')
        sign_in user
      end

      it 'denies write access' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'openssh'
        }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when authenticated with write access' do
      before { sign_in user }

      it 'replaces a single instance' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'openssh-daemon'
        }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['rule']['fixtext']).to include('openssh-daemon')
        expect(json['rule']['fixtext']).to include('sshd') # Second instance still there
      end

      it 'returns error for non-existent rule' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: 99_999,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'test'
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq('Rule not found')
      end

      it 'returns error for invalid field' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'invalid_field',
          instance_index: 0,
          replacement: 'test'
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['error']).to eq('Invalid field')
      end

      it 'returns error for out-of-bounds index' do
        post replace_instance_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 99,
          replacement: 'test'
        }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['error']).to eq('Instance not found')
      end

      it 'creates audit trail' do
        expect do
          post replace_instance_path, params: {
            search: 'sshd',
            rule_id: rule1.id,
            field: 'fixtext',
            instance_index: 0,
            replacement: 'openssh',
            audit_comment: 'Test replacement'
          }
        end.to change { rule1.audits.count }.by_at_least(1)
      end
    end
  end

  describe 'POST /api/components/:component_id/find_replace/replace_field' do
    let(:replace_field_path) { "/api/components/#{component.id}/find_replace/replace_field" }

    context 'when authenticated with write access' do
      before { sign_in user }

      it 'replaces all instances in a single field' do
        post replace_field_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          replacement: 'openssh-server'
        }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['replaced_count']).to eq(2)
        expect(json['rule']['fixtext']).not_to include('sshd')
        expect(json['rule']['fixtext'].scan('openssh-server').size).to eq(2)
      end

      it 'returns replaced count' do
        post replace_field_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          replacement: 'new-daemon'
        }

        json = response.parsed_body
        expect(json['replaced_count']).to eq(2)
      end
    end
  end

  describe 'POST /api/components/:component_id/find_replace/replace_all' do
    let(:replace_all_path) { "/api/components/#{component.id}/find_replace/replace_all" }

    context 'when authenticated with write access' do
      before { sign_in user }

      it 'replaces all matches across all rules' do
        post replace_all_path, params: {
          search: 'sshd',
          replacement: 'secure-shell-daemon'
        }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['rules_updated']).to eq(2)
        expect(json['matches_replaced']).to be >= 4

        # Verify rules are actually updated
        rule1.reload
        rule2.reload
        expect(rule1.fixtext).not_to include('sshd')
        expect(rule2.fixtext).not_to include('sshd')
      end

      it 'respects field filtering' do
        post replace_all_path, params: {
          search: 'sshd',
          fields: ['title'],
          replacement: 'openssh'
        }

        json = response.parsed_body
        expect(json['rules_updated']).to eq(1) # Only rule1 has 'sshd' in title

        rule1.reload
        expect(rule1.title).to include('openssh')
        expect(rule1.fixtext).to include('sshd') # fixtext unchanged
      end
    end
  end

  describe 'POST /api/components/:component_id/find_replace/undo' do
    let(:undo_path) { "/api/components/#{component.id}/find_replace/undo" }

    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        post undo_path, params: { rule_id: rule1.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated with write access' do
      before { sign_in user }

      it 'undoes the last Find & Replace operation' do
        # First, make a replacement
        replace_path = "/api/components/#{component.id}/find_replace/replace_instance"
        post replace_path, params: {
          search: 'sshd',
          rule_id: rule1.id,
          field: 'fixtext',
          instance_index: 0,
          replacement: 'openssh-daemon',
          audit_comment: 'Find & Replace - test'
        }

        # Verify replacement happened
        rule1.reload
        expect(rule1.fixtext).to include('openssh-daemon')

        # Now undo it
        post undo_path, params: { rule_id: rule1.id }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['reverted_fields']).to include('fixtext')
        expect(json['rule']['fixtext']).to include('sshd')
      end

      it 'returns error for non-existent rule' do
        post undo_path, params: { rule_id: 99_999 }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq('Rule not found')
      end

      it 'returns error when nothing to undo' do
        # Rule has no Find & Replace audits
        post undo_path, params: { rule_id: rule2.id }

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['error']).to eq('Nothing to undo')
      end

      it 'requires rule_id parameter' do
        post undo_path, params: {}

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when authenticated as viewer (read-only)' do
      before do
        Membership.find_by(user: user, membership: project).update!(role: 'viewer')
        sign_in user
      end

      it 'denies write access' do
        post undo_path, params: { rule_id: rule1.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'component not found' do
    before { sign_in user }

    it 'returns 404 for non-existent component' do
      post '/api/components/99999/find_replace/find', params: { search: 'test' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
