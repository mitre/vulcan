# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'climate_control'

RSpec.describe 'admin:bootstrap rake task' do
  let(:bootstrap_task) { 'admin:bootstrap' }
  let(:bootstrap_email) { "bootstrap-admin-#{Process.pid}@example.com" }
  let(:bootstrap_password) { 'SecurePass!@1234' }

  before(:all) do
    Rails.application.load_tasks
  end

  after do
    User.where('email LIKE ?', "%-#{Process.pid}@example.com").destroy_all
  end

  describe 'admin:bootstrap' do
    context 'when VULCAN_ADMIN_EMAIL and VULCAN_ADMIN_PASSWORD are set' do
      it 'creates an admin user with those credentials' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: bootstrap_email, VULCAN_ADMIN_PASSWORD: bootstrap_password) do
          expect { Rake::Task[bootstrap_task].invoke }.to change(User.where(admin: true), :count).by(1)

          admin = User.find_by(email: bootstrap_email)
          expect(admin).to be_present
          expect(admin.admin).to be true
          expect(admin.valid_password?(bootstrap_password)).to be true
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end

      it 'skips creation if admin already exists' do
        create(:user, email: "existing-admin-#{Process.pid}@example.com", admin: true)

        ClimateControl.modify(VULCAN_ADMIN_EMAIL: bootstrap_email, VULCAN_ADMIN_PASSWORD: bootstrap_password) do
          allow(Rails.logger).to receive(:info)
          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
          expect(Rails.logger).to have_received(:info).with(/Admin user already exists/).at_least(:once)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end

      it 'promotes existing non-admin user with matching email to admin' do
        existing_user = create(:user, email: bootstrap_email, admin: false)

        ClimateControl.modify(VULCAN_ADMIN_EMAIL: bootstrap_email, VULCAN_ADMIN_PASSWORD: bootstrap_password) do
          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)

          existing_user.reload
          expect(existing_user.admin).to be true
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end

      it 'is idempotent — safe to run multiple times' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: bootstrap_email, VULCAN_ADMIN_PASSWORD: bootstrap_password) do
          Rake::Task[bootstrap_task].invoke
          Rake::Task[bootstrap_task].reenable

          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end
    end

    context 'when only VULCAN_ADMIN_EMAIL is set (no password)' do
      let(:no_password_email) { "no-password-admin-#{Process.pid}@example.com" }

      it 'creates admin with a generated password and logs it' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: no_password_email) do
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:warn)

          expect { Rake::Task[bootstrap_task].invoke }.to change(User.where(admin: true), :count).by(1)

          admin = User.find_by(email: no_password_email)
          expect(admin).to be_present
          expect(admin.admin).to be true
          expect(Rails.logger).to have_received(:warn).with(/Generated temporary password/).at_least(:once)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end
    end

    context 'when neither VULCAN_ADMIN_EMAIL nor VULCAN_ADMIN_PASSWORD is set' do
      it 'does not create any admin user' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: nil, VULCAN_ADMIN_PASSWORD: nil) do
          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end

      it 'logs that no admin was bootstrapped' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: nil, VULCAN_ADMIN_PASSWORD: nil) do
          allow(Rails.logger).to receive(:info)
          Rake::Task[bootstrap_task].invoke
          expect(Rails.logger).to have_received(:info).with(/No VULCAN_ADMIN_EMAIL set/).at_least(:once)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end
    end

    context 'with invalid email format' do
      it 'logs an error and does not create user' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: 'not-a-valid-email', VULCAN_ADMIN_PASSWORD: bootstrap_password) do
          allow(Rails.logger).to receive(:error)
          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
          expect(Rails.logger).to have_received(:error).with(/Failed to create admin/).at_least(:once)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end
    end

    context 'with password that does not meet requirements' do
      it 'logs an error and does not create user' do
        ClimateControl.modify(VULCAN_ADMIN_EMAIL: "weak-password-admin-#{Process.pid}@example.com",
                              VULCAN_ADMIN_PASSWORD: 'weak') do
          allow(Rails.logger).to receive(:error)
          expect { Rake::Task[bootstrap_task].invoke }.not_to change(User, :count)
          expect(Rails.logger).to have_received(:error).with(/Failed to create admin/).at_least(:once)
        ensure
          Rake::Task[bootstrap_task].reenable
        end
      end
    end
  end
end
