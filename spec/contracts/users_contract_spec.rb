# frozen_string_literal: true

require 'rails_helper'
require 'openapi_first'
require_relative 'support/openapi_contract_helpers'

RSpec.describe 'Users endpoint contracts', type: :request do
  include Devise::Test::IntegrationHelpers
  include OpenAPIContractHelpers

  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:target_user) { create(:user, name: 'Contract Target', email: "target-#{SecureRandom.hex(4)}@example.com") }

  before do
    Rails.application.reload_routes!
    sign_in admin
  end

  # ── GET /users ──

  describe 'GET /users (JSON)' do
    it 'returns UserSummary array with all 8 fields pinned to real data' do
      get '/users', headers: json_headers
      body = validate_and_parse!

      expect(body).to be_an(Array)
      expect(body.size).to be >= 2

      admin_row = body.find { |u| u['id'] == admin.id }
      expect(admin_row).not_to be_nil, "Admin user #{admin.id} not found in response"
      assert_fields_present admin_row, :id, :name, :email, :provider, :admin,
                            :last_sign_in_at, :failed_attempts, :locked_at
      expect(admin_row['email']).to eq(admin.email)
      expect(admin_row['admin']).to be(true)
    end
  end

  # ── PUT /users/:id ──

  describe 'PUT /users/:id (JSON)' do
    it 'returns UserToastResponse with updated user and all 8 fields' do
      put "/users/#{target_user.id}",
          params: { user: { name: 'Updated Name' } },
          headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :user
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['user']['id']).to eq(target_user.id)
      expect(body['user']['name']).to eq('Updated Name')
      assert_fields_present body['user'], :id, :name, :email, :provider, :admin,
                            :last_sign_in_at, :failed_attempts, :locked_at
    end

    it 'returns 422 when last admin tries to demote self' do
      User.where(admin: true).where.not(id: admin.id).update_all(admin: false)
      put "/users/#{admin.id}",
          params: { user: { admin: false } },
          headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_content)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to include('Cannot')
    end
  end

  # ── DELETE /users/:id ──

  describe 'DELETE /users/:id (JSON)' do
    let!(:deletable_user) { create(:user, name: 'Deletable', email: "delete-#{SecureRandom.hex(4)}@example.com") }

    it 'returns ToastResponse on success' do
      delete "/users/#{deletable_user.id}", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('User removed.')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :user
    end

    it 'returns 422 when deleting the last admin' do
      # Make sure admin is the only admin
      User.where(admin: true).where.not(id: admin.id).update_all(admin: false)
      delete "/users/#{admin.id}", headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_entity)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to include('Cannot')
    end
  end

  # ── GET /users/:id/comments ──

  describe 'GET /users/:id/comments (JSON)' do
    let_it_be(:project) { create(:project, name: 'User Comments Test') }
    let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
    let_it_be(:component) { create(:component, project: project, based_on: srg, name: 'UC Test Comp') }
    let_it_be(:membership) do
      Membership.find_or_create_by!(user: admin, membership: project, membership_type: 'Project') do |m|
        m.role = 'admin'
      end
    end
    let_it_be(:rule) { component.rules.first || create(:rule, component: component) }
    let_it_be(:user_comment) do
      create(:review, user: admin, rule: rule, action: 'comment',
                      comment: 'User comments contract test', section: 'fixtext')
    end

    it 'returns paginated user comments with project/component context' do
      get "/users/#{admin.id}/comments", headers: json_headers
      body = validate_and_parse!

      assert_fields_present body, :rows, :pagination
      assert_fields_present body['pagination'], :page, :per_page, :total
      assert_fields_absent body, :status_counts, :total_comments

      expect(body['rows']).to be_an(Array)
      if body['rows'].any?
        row = body['rows'].first
        assert_fields_present row, :id, :project_id, :project_name, :component_id,
                              :component_name, :rule_displayed_name, :commentable_type,
                              :comment, :created_at, :triage_status, :responses_count, :reactions
        assert_fields_present row['reactions'], :up, :down, :mine
        assert_fields_absent row, :author_name, :author_email, :triager_display_name,
                             :rule_status, :group_rule_displayed_name
      end
    end
  end

  # ── POST /users/admin_create ──

  describe 'POST /users/admin_create' do
    it 'returns AdminCreateResponse with canonical toast + user (password provided)' do
      post '/users/admin_create',
           params: { user: { name: 'New Contract User',
                             email: "new-contract-#{SecureRandom.hex(4)}@example.com",
                             admin: false, password: 'TestPassword1234!@#$' } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :user
      expect(body['toast']).to be_a(Hash)
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to eq('User created.')
      assert_fields_present body['user'], :id, :name, :email, :provider, :admin,
                            :last_sign_in_at, :failed_attempts, :locked_at
      expect(body['user']['name']).to eq('New Contract User')
    end

    it 'returns AdminCreateResponse with reset_url when SMTP disabled and no password' do
      allow(Settings.smtp).to receive(:enabled).and_return(false)
      post '/users/admin_create',
           params: { user: { name: 'No SMTP User',
                             email: "nosmtp-#{SecureRandom.hex(4)}@example.com" } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :user, :reset_url
      expect(body['toast']).to be_a(Hash)
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['reset_url']).to include('/users/password/edit?reset_password_token=')
    end
  end

  # ── POST /users/:id/send_password_reset ──

  describe 'POST /users/:id/send_password_reset' do
    it 'returns 422 ToastResponse when SMTP is disabled' do
      allow(Settings.smtp).to receive(:enabled).and_return(false)
      post "/users/#{target_user.id}/send_password_reset", headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_entity)

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to include('SMTP')
    end
  end

  # ── POST /users/:id/generate_reset_link ──

  describe 'POST /users/:id/generate_reset_link' do
    it 'returns ResetLinkResponse with toast and reset_url' do
      post "/users/#{target_user.id}/generate_reset_link", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :reset_url
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['reset_url']).to include('/users/password/edit?reset_password_token=')
    end
  end

  # ── POST /users/:id/set_password ──

  describe 'POST /users/:id/set_password' do
    it 'returns ToastResponse on success with password changed confirmation' do
      post "/users/#{target_user.id}/set_password",
           params: { user: { password: 'NewPass1234!@#$' } },
           headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body.dig('toast', 'title')).to include('Password')
      expect(body.dig('toast', 'message')).to be_an(Array)
    end

    it 'returns 422 with danger toast when password is blank' do
      post "/users/#{target_user.id}/set_password",
           params: { user: { password: '' } },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_entity)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to be_a(String)
      expect(body.dig('toast', 'message')).to be_an(Array)
      expect(body.dig('toast', 'message').first).to be_a(String)
    end
  end

  # ── POST /users/:id/lock ──

  describe 'POST /users/:id/lock' do
    it 'returns UserToastResponse with locked_at set' do
      post "/users/#{target_user.id}/lock", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :user
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['user']['id']).to eq(target_user.id)
      expect(body['user']['locked_at']).not_to be_nil
      assert_fields_present body['user'], :id, :name, :email, :provider, :admin,
                            :last_sign_in_at, :failed_attempts, :locked_at
    end

    it 'returns 422 with danger toast when locking self' do
      post "/users/#{admin.id}/lock", headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_entity)

      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to include('Cannot')
      expect(body.dig('toast', 'message')).to be_an(Array)
      assert_fields_absent body, :user
    end
  end

  # ── POST /users/:id/unlock ──

  describe 'POST /users/:id/unlock' do
    before { target_user.lock_access!(send_instructions: false) }

    it 'returns UserToastResponse with locked_at cleared' do
      post "/users/#{target_user.id}/unlock", headers: json_headers, as: :json
      body = validate_and_parse!

      assert_fields_present body, :toast, :user
      expect(body.dig('toast', 'variant')).to eq('success')
      expect(body['user']['id']).to eq(target_user.id)
      expect(body['user']['locked_at']).to be_nil
    end
  end

  # ── POST /users/unlink_identity ──

  describe 'POST /users/unlink_identity' do
    it 'returns 422 with danger toast when user has no linked identity' do
      post '/users/unlink_identity',
           params: { current_password: 'password123!' },
           headers: json_headers, as: :json
      body = validate_and_parse!(expected_status: :unprocessable_entity)

      assert_fields_present body, :toast
      expect(body.dig('toast', 'variant')).to eq('danger')
      expect(body.dig('toast', 'title')).to be_a(String)
      expect(body.dig('toast', 'message')).to be_an(Array)
      expect(body.dig('toast', 'message').first).to include('unlink')
    end
  end
end
