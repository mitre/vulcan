# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users' do
  before do
    Rails.application.reload_routes!
  end

  # Use let! to ensure admin_user is created first (before regular_user/target_user)
  # This prevents regular_user from being promoted to admin by first-user-admin callback
  let!(:admin_user) { create(:user, admin: true) }
  let(:regular_user) { create(:user, admin: false) }
  let(:target_user) { create(:user, admin: false) }

  describe 'PUT /users/:id HTML format with admin user' do
    before { sign_in admin_user }

    let(:valid_params) { { user: { admin: true } } }

    it 'updates the user and redirects to index' do
      put "/users/#{target_user.id}", params: valid_params

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(users_path)

      target_user.reload
      expect(target_user.admin).to be true
    end

    it 'sets success flash message' do
      put "/users/#{target_user.id}", params: valid_params

      follow_redirect!
      expect(flash[:notice]).to eq('Successfully updated user.')
    end

    it 'sends slack notification when enabled' do
      allow(Settings.slack).to receive(:enabled).and_return(true)
      expect_any_instance_of(UsersController).to receive(:send_slack_notification)
        .with(:assign_vulcan_admin, target_user)

      put "/users/#{target_user.id}", params: valid_params
    end

    it 'does NOT send slack notification when only name changes (71q.1)' do
      allow(Settings.slack).to receive(:enabled).and_return(true)
      expect_any_instance_of(UsersController).not_to receive(:send_slack_notification)

      put "/users/#{target_user.id}", params: { user: { name: 'New Name' } }
    end

    it 'does NOT send slack notification when only email changes (71q.1)' do
      allow(Settings.slack).to receive(:enabled).and_return(true)
      expect_any_instance_of(UsersController).not_to receive(:send_slack_notification)

      put "/users/#{target_user.id}", params: { user: { email: 'newemail@example.com' } }
    end

    it 'sends demotion notification when admin flag removed (71q.1)' do
      target_user.update!(admin: true)
      allow(Settings.slack).to receive(:enabled).and_return(true)
      expect_any_instance_of(UsersController).to receive(:send_slack_notification)
        .with(:remove_vulcan_admin, target_user)

      put "/users/#{target_user.id}", params: { user: { admin: false } }
    end
  end

  describe 'PUT /users/:id JSON format with admin user' do
    before { sign_in admin_user }

    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }
    let(:valid_params) { { user: { admin: true } } }

    it 'updates the user and returns success JSON' do
      put "/users/#{target_user.id}", params: valid_params.to_json, headers: json_headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      json_response = response.parsed_body
      expect(json_response['toast']).to eq('Successfully updated user')

      target_user.reload
      expect(target_user.admin).to be true
    end

    it 'does not set flash messages for JSON requests' do
      put "/users/#{target_user.id}", params: valid_params.to_json, headers: json_headers

      expect(flash).to be_empty
    end
  end

  describe 'PUT /users/:id with non-admin user' do
    before { sign_in regular_user }

    it 'redirects with authorization error' do
      put "/users/#{target_user.id}", params: { user: { admin: true } }

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(flash[:alert]).to include('Please contact an administrator if you believe this message is in error')
    end
  end

  describe 'PUT /users/:id when not authenticated' do
    it 'redirects to login page' do
      put "/users/#{target_user.id}", params: { user: { admin: true } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'format handling regression prevention' do
    before { sign_in admin_user }

    it 'properly handles mixed HTML/JSON requests' do
      # Test that HTML requests get HTML responses
      put "/users/#{target_user.id}", params: { user: { admin: true } }
      expect(response).to have_http_status(:redirect)

      # Test that JSON requests get JSON responses
      json_headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
      put "/users/#{target_user.id}", params: { user: { admin: false } }.to_json, headers: json_headers
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'DELETE /users/:id HTML format' do
    before { sign_in admin_user }

    it 'destroys the user and redirects to index' do
      user_to_delete = target_user # ensure created

      expect do
        delete "/users/#{user_to_delete.id}"
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(users_path)
      follow_redirect!
      expect(flash[:notice]).to eq('Successfully removed user.')
    end
  end

  describe 'DELETE /users/:id JSON format' do
    before { sign_in admin_user }

    let(:json_headers) { { 'Accept' => 'application/json' } }

    it 'destroys the user and returns success JSON' do
      user_to_delete = target_user # ensure created

      expect do
        delete "/users/#{user_to_delete.id}", headers: json_headers
      end.to change(User, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
      json = response.parsed_body
      expect(json['toast']).to eq('Successfully removed user.')
    end

    it 'returns JSON error response on failure' do
      user_to_delete = target_user # Ensure user created before mocking

      allow_any_instance_of(User).to receive(:destroy).and_return(false)
      allow_any_instance_of(User).to receive_message_chain(:errors, :full_messages).and_return(['Cannot delete'])

      delete "/users/#{user_to_delete.id}", headers: json_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.content_type).to include('application/json')
      json = response.parsed_body
      expect(json['toast']['title']).to include('Could not remove')
    end
  end

  describe 'DELETE /users/:id with non-admin user' do
    before { sign_in regular_user }

    it 'redirects with authorization error' do
      delete "/users/#{target_user.id}"

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'last admin protection' do
    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

    before { sign_in admin_user }

    context 'when demoting the only admin' do
      it 'returns 422 via JSON' do
        put "/users/#{admin_user.id}", params: { user: { admin: false } }.to_json, headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['toast']['title']).to include('Cannot remove admin')
      end

      it 'prevents demotion via HTML' do
        put "/users/#{admin_user.id}", params: { user: { admin: false } }

        expect(response).to redirect_to(users_path)
        admin_user.reload
        expect(admin_user.admin).to be true
      end
    end

    context 'when deleting the only admin' do
      it 'returns 422 via JSON' do
        delete "/users/#{admin_user.id}", headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['toast']['title']).to include('Cannot delete')
      end

      it 'redirects with error via HTML' do
        delete "/users/#{admin_user.id}"

        expect(response).to redirect_to(users_path)
        follow_redirect!
        expect(flash[:alert]).to include('only admin')
      end
    end

    context 'when multiple admins exist' do
      let!(:second_admin) { create(:user, admin: true) }

      it 'allows demoting an admin' do
        put "/users/#{admin_user.id}", params: { user: { admin: false } }.to_json, headers: json_headers

        expect(response).to have_http_status(:ok)
        admin_user.reload
        expect(admin_user.admin).to be false
      end

      it 'allows deleting an admin' do
        expect do
          delete "/users/#{second_admin.id}", headers: json_headers
        end.to change(User, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /users/admin_create' do
    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

    context 'when admin' do
      before { sign_in admin_user }

      it 'creates a new user and returns JSON' do
        expect do
          post '/users/admin_create', params: { user: { name: 'New User', email: 'newuser@example.com' } }.to_json,
                                      headers: json_headers
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['toast']).to include('newuser@example.com')
        expect(json['user']['email']).to eq('newuser@example.com')
        expect(json['user']['name']).to eq('New User')
      end

      it 'creates user with admin flag' do
        post '/users/admin_create', params: { user: { name: 'Admin User', email: 'admin2@example.com', admin: true } }.to_json,
                                    headers: json_headers

        expect(response).to have_http_status(:ok)
        created = User.find_by(email: 'admin2@example.com')
        expect(created.admin).to be true
      end

      it 'skips confirmation on created user' do
        post '/users/admin_create', params: { user: { name: 'No Confirm', email: 'noconfirm@example.com' } }.to_json,
                                    headers: json_headers

        created = User.find_by(email: 'noconfirm@example.com')
        expect(created.confirmed?).to be true
      end

      it 'returns 422 for duplicate email' do
        post '/users/admin_create', params: { user: { name: 'Dup', email: admin_user.email } }.to_json,
                                    headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['toast']['variant']).to eq('danger')
      end

      it 'returns 422 for missing name' do
        post '/users/admin_create', params: { user: { name: '', email: 'valid@example.com' } }.to_json,
                                    headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when non-admin' do
      before { sign_in regular_user }

      it 'blocks access' do
        post '/users/admin_create', params: { user: { name: 'Blocked', email: 'blocked@example.com' } }

        expect(response).to redirect_to(root_path)
      end
    end

    context 'when not authenticated' do
      it 'redirects to login' do
        post '/users/admin_create', params: { user: { name: 'Anon', email: 'anon@example.com' } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'PUT /users/:id expanded update' do
    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }

    before { sign_in admin_user }

    it 'updates user name' do
      put "/users/#{target_user.id}", params: { user: { name: 'Updated Name' } }.to_json,
                                      headers: json_headers

      expect(response).to have_http_status(:ok)
      target_user.reload
      expect(target_user.name).to eq('Updated Name')
    end

    it 'updates user email' do
      put "/users/#{target_user.id}", params: { user: { email: 'newemail@example.com' } }.to_json,
                                      headers: json_headers

      expect(response).to have_http_status(:ok)
      target_user.reload
      expect(target_user.email).to eq('newemail@example.com')
    end

    it 'skips reconfirmation on email change' do
      put "/users/#{target_user.id}", params: { user: { email: 'changed@example.com' } }.to_json,
                                      headers: json_headers

      target_user.reload
      expect(target_user.email).to eq('changed@example.com')
      expect(target_user.unconfirmed_email).to be_nil
    end
  end

  describe 'POST /users/:id/send_password_reset' do
    let(:json_headers) { { 'Accept' => 'application/json' } }

    context 'when admin' do
      before { sign_in admin_user }

      it 'sends reset instructions when SMTP is enabled' do
        allow(Settings.smtp).to receive(:enabled).and_return(true)

        post "/users/#{target_user.id}/send_password_reset", headers: json_headers

        expect(response).to have_http_status(:ok),
                            "Expected 200 but got #{response.status}. Body: #{response.body.truncate(500)}"
        json = response.parsed_body
        expect(json['toast']).to include('Password reset')
        expect(json['toast']).to include(target_user.email)
      end

      it 'does not leak exception message on internal error (71q.5)' do
        allow(Settings.smtp).to receive(:enabled).and_return(true)
        allow_any_instance_of(User).to receive(:send_reset_password_instructions)
          .and_raise(StandardError, 'SMTP server at smtp.internal.corp:587 refused connection')

        post "/users/#{target_user.id}/send_password_reset", headers: json_headers

        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body
        # Must NOT contain the internal error details
        expect(json.to_s).not_to include('smtp.internal.corp')
        expect(json.to_s).not_to include('refused connection')
        # Should have a generic message
        expect(json['toast']['title']).to include('Could not')
      end

      it 'returns 422 when SMTP is not configured' do
        allow(Settings.smtp).to receive(:enabled).and_return(false)

        post "/users/#{target_user.id}/send_password_reset", headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['toast']['title']).to include('SMTP not configured')
      end
    end

    context 'when non-admin' do
      before { sign_in regular_user }

      it 'blocks access' do
        post "/users/#{target_user.id}/send_password_reset"

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /users/:id/generate_reset_link' do
    let(:json_headers) { { 'Accept' => 'application/json' } }

    context 'when admin' do
      before { sign_in admin_user }

      it 'returns a reset URL without sending email' do
        post "/users/#{target_user.id}/generate_reset_link", headers: json_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['reset_url']).to include('reset_password_token=')
        expect(json['toast']).to include('Reset link generated')
      end

      it 'sets reset_password_token on the user' do
        post "/users/#{target_user.id}/generate_reset_link", headers: json_headers

        target_user.reload
        expect(target_user.reset_password_token).to be_present
        expect(target_user.reset_password_sent_at).to be_present
      end

      it 'returns a URL that Devise can validate' do
        post "/users/#{target_user.id}/generate_reset_link", headers: json_headers

        json = response.parsed_body
        token = json['reset_url'].match(/reset_password_token=([^&]+)/)[1]
        user = User.with_reset_password_token(token)
        expect(user).to eq(target_user)
      end

      it 'succeeds even when user has pre-existing validation failures (71q.4)' do
        # Simulate a user whose name exceeds current validators (e.g., limit was tightened after creation)
        target_user.update_columns(name: 'X' * 500)

        post "/users/#{target_user.id}/generate_reset_link", headers: json_headers

        expect(response).to have_http_status(:ok),
                            "Expected 200 but got #{response.status}. Body: #{response.body.truncate(500)}"
        target_user.reload
        expect(target_user.reset_password_token).to be_present
        expect(target_user.reset_password_sent_at).to be_present
      end
    end

    context 'when non-admin' do
      before { sign_in regular_user }

      it 'blocks access' do
        post "/users/#{target_user.id}/generate_reset_link"

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /users/:id/set_password' do
    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }
    let(:compliant_password) { 'N3wSecure!!Pass99' }

    context 'when admin' do
      before { sign_in admin_user }

      it 'sets the user password directly' do
        post "/users/#{target_user.id}/set_password",
             params: { user: { password: compliant_password } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:ok),
                            "Expected 200 but got #{response.status}. Body: #{response.body.truncate(500)}"
        json = response.parsed_body
        expect(json['toast']).to include(target_user.email)

        # Verify the password actually works
        target_user.reload
        expect(target_user.valid_password?(compliant_password)).to be true
      end

      it 'rescue block uses generic message, not exception details (71q.5)' do
        # Verify the rescue block in set_password does NOT interpolate e.message.
        # (Cannot test via request spec because Rails test mode re-raises exceptions
        # before the controller rescue runs. Verify via source inspection instead.)
        source = Rails.root.join('app/controllers/users_controller.rb').read
        set_password_section = source[/def set_password.*?^  end/m]
        expect(set_password_section).to include('rescue StandardError')
        expect(set_password_section).to include('Rails.logger.error')
        expect(set_password_section).not_to match(/message:.*e\.message/),
                                            'rescue block must not leak e.message to client'
      end

      it 'returns 422 for blank password' do
        post "/users/#{target_user.id}/set_password",
             params: { user: { password: '' } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns 422 for non-compliant password' do
        post "/users/#{target_user.id}/set_password",
             params: { user: { password: 'short' } }.to_json,
             headers: json_headers

        expect(response).to have_http_status(:unprocessable_content)
        json = response.parsed_body
        expect(json['toast']['variant']).to eq('danger')
      end
    end

    context 'when non-admin' do
      before { sign_in regular_user }

      it 'blocks access' do
        post "/users/#{target_user.id}/set_password"

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /users/admin_create with password' do
    let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } }
    let(:compliant_password) { 'N3wSecure!!Pass99' }

    before { sign_in admin_user }

    it 'creates user with admin-provided password when given' do
      post '/users/admin_create',
           params: { user: { name: 'Manual PW', email: 'manualpw@example.com', password: compliant_password } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      created = User.find_by(email: 'manualpw@example.com')
      expect(created.valid_password?(compliant_password)).to be true
    end

    it 'returns reset_url when no SMTP and no password provided' do
      allow(Settings.smtp).to receive(:enabled).and_return(false)

      post '/users/admin_create',
           params: { user: { name: 'No SMTP', email: 'nosmtp@example.com' } }.to_json,
           headers: json_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['reset_url']).to include('reset_password_token=')
    end
  end
end
