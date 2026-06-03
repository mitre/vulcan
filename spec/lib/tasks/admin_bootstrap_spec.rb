# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'admin:bootstrap rake task' do
  let(:bootstrap_task) { 'admin:bootstrap' }
  let(:bootstrap_email) { "bootstrap-admin-#{Process.pid}@example.com" }
  let(:bootstrap_password) { 'SecurePass!@1234' }

  before(:all) do
    Rails.application.load_tasks
  end

  after do
    ENV.delete('VULCAN_ADMIN_EMAIL')
    ENV.delete('VULCAN_ADMIN_PASSWORD')
    User.where('email LIKE ?', "%-#{Process.pid}@example.com").destroy_all
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
        create(:user, email: "existing-admin-#{Process.pid}@example.com", admin: true)

        allow(Rails.logger).to receive(:info)
        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
        expect(Rails.logger).to have_received(:info).with(/Admin user already exists/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'promotes existing non-admin user with matching email to admin' do
        existing_user = create(:user, email: bootstrap_email, admin: false)

        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

        existing_user.reload
        expect(existing_user.admin).to be true
      ensure
        Rake::Task[bootstrap_task].reenable
      end

      it 'is idempotent — safe to run multiple times' do
        Rake::Task[bootstrap_task].invoke
        Rake::Task[bootstrap_task].reenable

        expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'when only VULCAN_ADMIN_EMAIL is set (no password)' do
      before do
        ENV['VULCAN_ADMIN_EMAIL'] = "no-password-admin-#{Process.pid}@example.com"
        ENV.delete('VULCAN_ADMIN_PASSWORD')
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)
      end

      it 'creates admin with a generated password and logs it' do
        expect { Rake::Task[bootstrap_task].invoke }.to change(User.where(admin: true), :count).by(1)

        admin = User.find_by(email: "no-password-admin-#{Process.pid}@example.com")
        expect(admin).to be_present
        expect(admin.admin).to be true
        expect(Rails.logger).to have_received(:warn).with(/Generated temporary password/)
      ensure
        Rake::Task[bootstrap_task].reenable
      end
    end

    context 'when neither VULCAN_ADMIN_EMAIL nor VULCAN_ADMIN_PASSWORD is set' do
      before do
        ENV.delete('VULCAN_ADMIN_EMAIL')
        ENV.delete('VULCAN_ADMIN_PASSWORD')
        allow(Rails.logger).to receive(:info)
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
        allow(Rails.logger).to receive(:error)
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
        ENV['VULCAN_ADMIN_EMAIL'] = "weak-password-admin-#{Process.pid}@example.com"
        ENV['VULCAN_ADMIN_PASSWORD'] = 'weak'
        allow(Rails.logger).to receive(:error)
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
