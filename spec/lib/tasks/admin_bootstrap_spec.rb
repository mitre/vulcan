# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'admin:bootstrap rake task' do
  let(:bootstrap_task) { 'admin:bootstrap' }
  let(:bootstrap_email) { 'bootstrap-admin@example.com' }
  let(:bootstrap_password) { 'SecurePass!@1234' }

  before(:all) do
    Rails.application.load_tasks
  end

  before do
    # Clear any existing admin users
    User.where(admin: true).destroy_all

    # Allow logging
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  after do
    # Clean up env vars
    ENV.delete('VULCAN_ADMIN_EMAIL')
    ENV.delete('VULCAN_ADMIN_PASSWORD')
  end

  describe 'admin:bootstrap' do
    context 'when VULCAN_ADMIN_EMAIL and VULCAN_ADMIN_PASSWORD are set' do
      before do
        ENV['VULCAN_ADMIN_EMAIL'] = bootstrap_email
        ENV['VULCAN_ADMIN_PASSWORD'] = bootstrap_password
      end

      it 'creates an admin user with those credentials' do
        expect { Rake::Task[bootstrap_task].invoke }.to change(User.where(admin: true), :count).by(1)

        admin = User.find_by(email: bootstrap_email)
        expect(admin).to be_present
        expect(admin.admin).to be true
        expect(admin.valid_password?(bootstrap_password)).to be true
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'skips creation if admin already exists' do
        # Create an admin first
        create(:user, admin: true)

        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

        expect(Rails.logger).to have_received(:info).with(/Admin user already exists/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'promotes existing non-admin user with matching email to admin' do
        # Create a non-admin user with the same email
        existing_user = create(:user, email: bootstrap_email, admin: false)

        # Should not create new user, but should promote existing one
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

        # The existing user should be promoted to admin
        existing_user.reload
        expect(existing_user.admin).to be true
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'is idempotent - safe to run multiple times' do
        # First run creates admin
        Rake::Task[bootstrap_task].invoke
        Rake::Task[bootstrap_task].reenable

        # Second run should not fail or create duplicate
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'when only VULCAN_ADMIN_EMAIL is set (no password)' do
      before do
        ENV['VULCAN_ADMIN_EMAIL'] = 'no-password-admin@example.com'
        ENV.delete('VULCAN_ADMIN_PASSWORD')
      end

      it 'creates admin with a generated password and logs it' do
        expect { Rake::Task[bootstrap_task].invoke }.to change(User.where(admin: true), :count).by(1)

        admin = User.find_by(email: 'no-password-admin@example.com')
        expect(admin).to be_present
        expect(admin.admin).to be true

        # Password should be generated (we can't know what it is, but user should exist)
        expect(Rails.logger).to have_received(:warn).with(/Generated temporary password/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'when neither VULCAN_ADMIN_EMAIL nor VULCAN_ADMIN_PASSWORD is set' do
      before do
        ENV.delete('VULCAN_ADMIN_EMAIL')
        ENV.delete('VULCAN_ADMIN_PASSWORD')
      end

      it 'does not create any admin user' do
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'logs that no admin was bootstrapped' do
        Rake::Task[bootstrap_task].invoke

        expect(Rails.logger).to have_received(:info).with(/No VULCAN_ADMIN_EMAIL set/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'with invalid email format' do
      before do
        ENV['VULCAN_ADMIN_EMAIL'] = 'not-a-valid-email'
        ENV['VULCAN_ADMIN_PASSWORD'] = bootstrap_password
      end

      it 'logs an error and does not create user' do
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

        expect(Rails.logger).to have_received(:error).with(/Failed to create admin/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'with password that does not meet requirements' do
      before do
        ENV['VULCAN_ADMIN_EMAIL'] = 'weak-password-admin@example.com'
        ENV['VULCAN_ADMIN_PASSWORD'] = 'weak'
      end

      it 'logs an error and does not create user' do
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

        expect(Rails.logger).to have_received(:error).with(/Failed to create admin/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end
  end
end
