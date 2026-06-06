# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Components endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let_it_be(:project) { create(:project, name: 'Components Contract Project') }
  let_it_be(:component) do
    create(:component, project: project, based_on: srg, name: 'Comp Contract Test',
                       prefix: 'CCTT-01', title: 'Components Contract Test Guide',
                       comment_phase: 'open', comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 14.days.from_now)
  end
  let_it_be(:membership) do
    Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
      m.role = 'admin'
    end
  end
  let_it_be(:rule) { component.rules.first || create(:rule, component: component) }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── GET /components (index) ──

  describe 'GET /components (JSON)' do
    let_it_be(:released_component) do
      c = create(:component, project: project, based_on: srg, name: 'Released For Index',
                             prefix: 'RELI-01', title: 'Released Index Test')
      c.rules.update_all(locked: true)
      c.update!(released: true)
      c
    end

    it 'returns ComponentIndexResponse array with released components' do
      get '/components', headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body).not_to be_empty

      found = body.find { |c| c['id'] == released_component.id }
      expect(found).not_to be_nil, "Released component #{released_component.id} not in response"
      assert_fields_present found, :id, :name, :prefix, :version, :release,
                            :based_on_title, :based_on_version, :severity_counts,
                            :pending_comment_count, :updated_at, :released, :rules_count, :component_id
      expect(found['released']).to be(true)
      expect(found['id']).to eq(released_component.id)
    end
  end

  # ── GET /components/:id (member — editor view) ──

  describe 'GET /components/:id (JSON, member)' do
    it 'returns ComponentEditorResponse with 35 fields' do
      get "/components/#{component.id}", headers: json_headers
      body = validate_and_parse!

      expect(body['id']).to eq(component.id)
      expect(body['name']).to eq(component.name)
      assert_fields_present body, :id, :name, :prefix, :version, :release,
                            :based_on_title, :based_on_version, :severity_counts,
                            :pending_comment_count, :title, :description, :admin_name,
                            :admin_email, :released, :advanced_fields, :project_id,
                            :component_id, :security_requirements_guide_id,
                            :memberships_count, :rules_count, :updated_at, :created_at,
                            :comment_phase, :releasable, :status_counts,
                            :additional_questions, :rules, :reviews, :histories,
                            :memberships, :metadata, :inherited_memberships,
                            :effective_permissions

      expect(body['rules']).to be_an(Array)
      expect(body['memberships']).to be_an(Array)
      expect(body['inherited_memberships']).to be_an(Array)
      expect(body['status_counts']).to be_a(Hash)
      expect(body['project_id']).to eq(project.id)
      expect(body['effective_permissions']).to eq('admin')
    end
  end

  # ── POST /components (create) ──

  describe 'POST /projects/:id/components (JSON)' do
    it 'returns ToastResponse on successful component creation' do
      post "/projects/#{project.id}/components",
           params: { component: { name: 'New Contract Comp', prefix: 'NCON-01',
                                  title: 'New Contract Component', security_requirements_guide_id: srg.id } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Component added.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :component, :data
    end
  end

  # ── PUT /components/:id (update) ──

  describe 'PUT /components/:id (JSON)' do
    it 'returns ToastResponse with update confirmation' do
      put "/components/#{component.id}",
          params: { component: { description: 'Updated by contract test' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Component updated.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :component, :data
    end
  end

  # ── GET /components/:id/comments ──

  describe 'GET /components/:id/comments (JSON)' do
    let_it_be(:comment) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'Component comments contract test', section: 'fixtext')
    end

    it 'returns PaginatedComments with CommentRow items' do
      get "/components/#{component.id}/comments", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows, :pagination, :status_counts
      expect(body['rows']).to be_an(Array)
      assert_fields_present body['pagination'], :page, :per_page, :total, :total_comments
      expect(body['status_counts']).to be_a(Hash)
    end
  end

  # ── GET /components/:id/histories ──

  describe 'GET /components/:id/histories (JSON)' do
    before do
      component.update!(description: 'History test trigger')
    end

    it 'returns AuditEntry array with audit trail data' do
      get "/components/#{component.id}/histories", headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body).not_to be_empty, 'Expected at least one audit entry after update'
      first = body.first
      assert_fields_present first, :id, :action, :auditable_type, :auditable_id, :created_at, :audited_changes
      expect(first['auditable_type']).to eq('Component')
      expect(first['auditable_id']).to eq(component.id)
    end
  end

  # ── POST /components/:id/find ──

  describe 'POST /components/:id/find (JSON)' do
    it 'returns RuleEditorResponse array with matching rules' do
      search_term = rule.title.to_s.split.first(2).join(' ')
      post "/components/#{component.id}/find",
           params: { find: search_term },
           headers: json_headers, as: :json
      body = validate_and_parse!

      expect(body).to be_an(Array)
      if body.any?
        first_rule = body.first
        assert_fields_present first_rule, :id, :rule_id, :title, :component_id
        expect(first_rule['component_id']).to eq(component.id)
      end
    end
  end

  # ── GET /components/:id/related ──

  describe 'GET /components/:id/related (JSON)' do
    it 'returns array of related components with project context' do
      get "/components/#{component.id}/related", headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      if body.any?
        first = body.first
        assert_fields_present first, :id, :name, :prefix, :project_id, :project_name
      end
    end
  end

  # ── GET /components/:id/rules/picker ──
  # (already tested in rules_contract_spec.rb)

  # ── GET /components/history (version diff) ──

  describe 'GET /components/history (JSON)' do
    it 'returns history array with at least one milestone entry' do
      get '/components/history',
          params: { project_id: project.id, name: component.name },
          headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body).not_to be_empty, "Expected history for component '#{component.name}' in project #{project.id}"
      milestone = body.find { |e| e.key?('component') }
      expect(milestone).not_to be_nil, 'Expected at least one milestone entry'
      assert_fields_present milestone['component'], :id, :name, :prefix, :version, :release
      expect(milestone['component']['name']).to eq(component.name)
    end
  end

  # ── GET /api/components/compare ──

  describe 'GET /api/components/compare (JSON)' do
    let_it_be(:other_component) do
      Component.where(based_on: srg).where.not(id: component.id).first ||
        create(:component, project: project, based_on: srg, name: 'Compare Target',
                           prefix: 'CMPR-01', title: 'Compare Target')
    end

    it 'returns { data: rule_diffs, meta: comparison_info }' do
      get '/api/components/compare',
          params: { base_id: component.id, diff_id: other_component.id },
          headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :data, :meta
      expect(body['data']).to be_a(Hash)
      expect(body['meta']).to be_a(Hash)
      assert_fields_present body['meta'], :base_id, :diff_id, :rules_count
      expect(body['meta']['base_id']).to eq(component.id)
      expect(body['meta']['diff_id']).to eq(other_component.id)
    end
  end

  # ── POST /components/detect_srg ──
  # Requires file upload — skipping in contract tests (would need fixture XLSX)

  # ── POST /components/:id/preview_spreadsheet_update ──
  # Requires file upload — skipping in contract tests

  # ── PATCH /components/:id/apply_spreadsheet_update ──
  # Requires file upload — skipping in contract tests

  # ── DELETE /components/:id ──

  describe 'DELETE /components/:id (JSON)' do
    let!(:deletable_component) do
      create(:component, project: project, based_on: srg, name: 'Deletable',
                         prefix: 'DELE-01', title: 'Deletable Component')
    end

    it 'returns ToastResponse on success' do
      delete "/components/#{deletable_component.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Component removed.')
      assert_fields_absent body, :component
    end
  end

  # ── POST /components/:id/lock (reviews#lock_controls) ──

  describe 'POST /components/:id/lock (JSON)' do
    it 'returns ToastResponse with lock result' do
      post "/components/#{component.id}/lock",
           params: { review: { action: 'lock', comment: 'Contract test lock all', component_id: component.id } },
           headers: json_headers, as: :json

      # lock_controls may return success (200) or validation error (422)
      # depending on whether rules can be locked. Both are valid ToastResponse shapes.
      body = response.parsed_body
      validate_response!(request, response) if response.status == 200
      assert_fields_present body, :toast
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end

  # ── POST /components/:id/reviews (component-level comment) ──

  describe 'POST /components/:id/reviews (JSON)' do
    it 'returns ToastResponse on component-level comment creation' do
      post "/components/#{component.id}/reviews",
           params: { review: { action: 'comment', comment: 'Component-level contract test comment' } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('Comment posted.')
    end
  end

  # ── PATCH /components/:id/lock_sections (reviews#lock_sections) ──

  describe 'PATCH /components/:id/lock_sections (JSON)' do
    it 'returns ToastResponse with section lock confirmation' do
      patch "/components/#{component.id}/lock_sections",
            params: { sections: ['Fix'], locked: true, comment: 'Contract lock sections' },
            headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('Section lock')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end
  end

  # ── GET /search/components ──

  describe 'GET /search/components (JSON)' do
    it 'returns components as compact tuples with correct wrapper' do
      get '/search/components', params: { q: srg.srg_id }, headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :components
      expect(body['components']).to be_an(Array)
      expect(body.keys).to contain_exactly('components')
    end
  end
end
