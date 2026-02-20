# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Locked user notifications' do
  before do
    Rails.application.reload_routes!
  end

  let(:admin) { create(:user, admin: true) }
  let(:regular_user) { create(:user) }

  describe 'navbar locked_users data' do
    context 'when lockout is enabled and user is admin' do
      before do
        allow(Settings).to receive_message_chain(:lockout, :enabled).and_return(true)
      end

      it 'includes locked users in navbar data' do
        locked_user = create(:user, locked_at: 1.hour.ago, failed_attempts: 3)
        sign_in admin
        get projects_path
        expect(response.body).to include('locked_users')
        expect(response.body).to include(locked_user.email)
      end

      it 'does not include unlocked users' do
        create(:user, locked_at: nil, failed_attempts: 0)
        sign_in admin
        get projects_path
        # The locked_users array should be empty (rendered as [])
        expect(response.body).to match(/locked_users.*\[\]/)
      end
    end

    context 'when lockout is disabled' do
      before do
        allow(Settings).to receive_message_chain(:lockout, :enabled).and_return(false)
      end

      it 'passes empty locked_users' do
        create(:user, locked_at: 1.hour.ago, failed_attempts: 3)
        sign_in admin
        get projects_path
        expect(response.body).to match(/locked_users.*\[\]/)
      end
    end

    context 'when user is not admin' do
      before do
        allow(Settings).to receive_message_chain(:lockout, :enabled).and_return(true)
      end

      it 'passes empty locked_users' do
        create(:user, locked_at: 1.hour.ago, failed_attempts: 3)
        sign_in regular_user
        get projects_path
        expect(response.body).to match(/locked_users.*\[\]/)
      end
    end
  end
end
