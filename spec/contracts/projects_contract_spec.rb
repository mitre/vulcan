# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Projects endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:project) { create(:project, name: 'Projects Contract Test') }
  let_it_be(:component) do
    create(:component, project: project, based_on: srg, name: 'Proj Contract Comp',
                       prefix: 'PJCT-01', title: 'Projects Contract Component')
  end
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── GET /projects ──

  describe 'GET /projects (JSON)' do
    it 'returns ProjectIndexResponse array with per-user computed fields' do
      get '/projects', headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body).not_to be_empty

      found = body.find { |p| p['id'] == project.id }
      expect(found).not_to be_nil, "Project #{project.id} not in response"
      assert_fields_present found, :id, :name, :description, :visibility, :memberships_count,
                            :admin_name, :admin_email, :created_at, :updated_at,
                            :memberships, :admin, :is_member, :access_request_id,
                            :pending_comment_count, :total_comment_count, :pending_comment_link
      expect(found['id']).to eq(project.id)
      expect(found['admin']).to be(true)
      expect(found['is_member']).to be(true)
      expect(found['memberships']).to be_an(Array)
    end
  end

  # ── POST /projects ──

  describe 'POST /projects (JSON)' do
    it 'returns ProjectCreateResponse with toast + redirect_url' do
      post '/projects',
           params: { project: { name: "New Project #{SecureRandom.hex(4)}", description: 'test' } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :redirect_url
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Project created.')
      expect(body['redirect_url']).to start_with('/projects/')
      assert_fields_absent body, :project
    end
  end

  # ── GET /projects/:id ──

  describe 'GET /projects/:id (JSON)' do
    it 'returns ProjectShowResponse with 18 fields including nested collections' do
      get "/projects/#{project.id}", headers: json_headers
      body = validate_and_parse!

      expect(body['id']).to eq(project.id)
      expect(body['name']).to eq(project.name)
      assert_fields_present body, :id, :name, :description, :visibility, :memberships_count,
                            :admin_name, :admin_email, :created_at, :updated_at,
                            :pending_comment_count, :details, :histories, :metadata,
                            :memberships, :components, :available_components, :users,
                            :access_requests, :effective_permissions
      expect(body['memberships']).to be_an(Array)
      expect(body['components']).to be_an(Array)
      expect(body['users']).to be_an(Array)
      expect(body['access_requests']).to be_an(Array)
      expect(body['histories']).to be_an(Array)
      expect(body['effective_permissions']).to eq('admin')
    end
  end

  # ── PUT /projects/:id ──

  describe 'PUT /projects/:id (JSON)' do
    it 'returns ToastResponse with update confirmation' do
      put "/projects/#{project.id}",
          params: { project: { description: 'Updated by contract test' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Project updated.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :project, :redirect_url
    end
  end

  # ── DELETE /projects/:id ──

  describe 'DELETE /projects/:id (JSON)' do
    let!(:deletable_project) { create(:project, name: "Delete Me #{SecureRandom.hex(4)}") }
    let!(:delete_membership) do
      Membership.find_or_create_by!(user: admin, membership: deletable_project, membership_type: 'Project') do |m|
        m.role = 'admin'
      end
    end

    it 'returns ToastResponse on success' do
      delete "/projects/#{deletable_project.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Project removed.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :project
    end
  end

  # ── GET /projects/:id/comments ──

  describe 'GET /projects/:id/comments (JSON)' do
    let_it_be(:rule) { component.rules.first || create(:rule, component: component) }
    let_it_be(:comment) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Project comments contract test', section: 'fixtext')
    end

    it 'returns project paginated comments with component context and status_counts' do
      get "/projects/#{project.id}/comments", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows, :pagination, :status_counts
      expect(body['rows']).to be_an(Array)
      assert_fields_present body['pagination'], :page, :per_page, :total
      assert_fields_absent body['pagination'], :total_comments
      expect(body['status_counts']).to be_a(Hash)

      if body['rows'].any?
        row = body['rows'].first
        assert_fields_present row, :id, :rule_displayed_name, :commentable_type,
                              :comment, :triage_status, :responses_count, :reactions
      end
    end
  end

  # ── GET /projects/:id/histories ──

  describe 'GET /projects/:id/histories (JSON)' do
    before { project.update!(description: 'History trigger for contract test') }

    it 'returns AuditEntry array with project audit trail pinned to project' do
      get "/projects/#{project.id}/histories", headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body).not_to be_empty, 'Expected at least one audit entry'
      first = body.first
      assert_fields_present first, :id, :action, :auditable_type, :auditable_id,
                            :name, :audited_name, :comment, :created_at, :audited_changes
      expect(first['auditable_type']).to eq('Project')
      expect(first['auditable_id']).to eq(project.id)
      expect(first['audited_changes']).to be_an(Array)
    end
  end

  # ── POST /memberships ──

  describe 'POST /memberships (JSON)' do
    let!(:new_member) { create(:user, name: 'New Member', email: "member-#{SecureRandom.hex(4)}@example.com") }

    it 'returns ToastResponse with membership created confirmation' do
      post '/memberships',
           params: { membership: { user_id: new_member.id, role: 'viewer',
                                   membership_type: 'Project', membership_id: project.id } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Membership created.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :membership
    end
  end

  # ── PUT /memberships/:id ──

  describe 'PUT /memberships/:id (JSON)' do
    let!(:updatable_member) { create(:user, name: 'Updatable', email: "update-#{SecureRandom.hex(4)}@example.com") }
    let!(:updatable_membership) do
      Membership.create!(user: updatable_member, membership: project, membership_type: 'Project', role: 'viewer')
    end

    it 'returns ToastResponse with role update confirmation' do
      put "/memberships/#{updatable_membership.id}",
          params: { membership: { role: 'author' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Membership updated.')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end

  # ── DELETE /memberships/:id ──

  describe 'DELETE /memberships/:id (JSON)' do
    let!(:removable_member) { create(:user, name: 'Removable', email: "remove-#{SecureRandom.hex(4)}@example.com") }
    let!(:removable_membership) do
      Membership.create!(user: removable_member, membership: project, membership_type: 'Project', role: 'viewer')
    end

    it 'returns ToastResponse with membership removed confirmation' do
      delete "/memberships/#{removable_membership.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Membership removed.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :membership
    end
  end

  # ── GET /search/projects ──

  describe 'GET /search/projects (JSON)' do
    it 'returns projects as compact tuples matching SRG query' do
      get '/search/projects', params: { q: srg.srg_id }, headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :projects
      expect(body['projects']).to be_an(Array)
      expect(body.keys).to contain_exactly('projects')

      if body['projects'].any?
        first_tuple = body['projects'].first
        expect(first_tuple).to be_an(Array)
        expect(first_tuple.size).to eq(2)
      end
    end
  end
end
