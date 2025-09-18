# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'default from address' do
    let(:mailer) { ApplicationMailer.new }
    let(:from_address) { mailer.default_params[:from].call }
    let(:contact_email) { 'contact@example.com' }
    let(:company_email) { 'support@company.com' }

    # Helper method to setup SMTP and contact email configuration
    def setup_email_config(smtp_enabled: false, smtp_username: nil, contact_email_override: nil, env: 'test')
      smtp_settings = smtp_username ? { 'user_name' => smtp_username } : {}
      email_to_use = contact_email_override || contact_email
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(env))
      allow(Settings.smtp).to receive_messages(enabled: smtp_enabled, settings: smtp_settings)
      allow(Settings).to receive(:contact_email).and_return(email_to_use)
    end

    # Helper method to expect from address equals expected email
    def expect_from_address(expected_email)
      expect(from_address).to eq(expected_email)
    end

    context 'when SMTP is disabled' do
      before { setup_email_config }

      it 'uses contact_email as from address' do
        expect_from_address(contact_email)
      end
    end

    context 'when SMTP is enabled but no username configured' do
      before { setup_email_config(smtp_enabled: true) }

      it 'falls back to contact_email' do
        expect_from_address(contact_email)
      end
    end

    context 'when SMTP is enabled with username configured in production' do
      before do
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'smtp-user@mailserver.com',
          env: 'production'
        )
      end

      it 'uses SMTP username as from address for authentication alignment' do
        expect_from_address('smtp-user@mailserver.com')
      end
    end

    context 'when SMTP is enabled with blank username' do
      before { setup_email_config(smtp_enabled: true, smtp_username: '') }

      it 'falls back to contact_email when username is blank' do
        expect_from_address(contact_email)
      end
    end

    context 'when SMTP is enabled with username in non-production environment' do
      before do
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'smtp-user@mailserver.com',
          env: 'test'
        )
      end

      it 'always uses contact_email in non-production environments' do
        expect_from_address(contact_email)
      end
    end

    context 'real-world email alignment scenarios' do
      it 'prevents Gmail/domain mismatch issues in production' do
        # Simulate the original problematic configuration
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'donotreply.vulcan@gmail.com',
          contact_email_override: 'saf@mitre.org',
          env: 'production'
        )

        # Should use SMTP username to prevent authentication mismatch
        expect_from_address('donotreply.vulcan@gmail.com')
      end

      it 'works correctly with professional email services in production' do
        # Simulate proper Mailgun/SendGrid setup
        setup_email_config(
          smtp_enabled: true,
          smtp_username: company_email,
          contact_email_override: company_email,
          env: 'production'
        )

        expect_from_address(company_email)
      end
    end
  end
end
