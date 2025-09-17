# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'default from address' do
    let(:mailer) { ApplicationMailer.new }
    let(:from_address) { mailer.default_params[:from].call }

    # Helper method to setup SMTP and contact email configuration
    def setup_email_config(smtp_enabled: false, smtp_username: nil, contact_email: 'contact@example.com')
      smtp_settings = smtp_username ? { 'user_name' => smtp_username } : {}
      allow(Settings.smtp).to receive_messages(enabled: smtp_enabled, settings: smtp_settings)
      allow(Settings).to receive(:contact_email).and_return(contact_email)
    end

    # Helper method to expect from address equals expected email
    def expect_from_address(expected_email)
      expect(from_address).to eq(expected_email)
    end

    context 'when SMTP is disabled' do
      before { setup_email_config }

      it 'uses contact_email as from address' do
        expect_from_address('contact@example.com')
      end
    end

    context 'when SMTP is enabled but no username configured' do
      before { setup_email_config(smtp_enabled: true) }

      it 'falls back to contact_email' do
        expect_from_address('contact@example.com')
      end
    end

    context 'when SMTP is enabled with username configured' do
      before do
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'smtp-user@mailserver.com'
        )
      end

      it 'uses SMTP username as from address for authentication alignment' do
        expect_from_address('smtp-user@mailserver.com')
      end
    end

    context 'when SMTP is enabled with blank username' do
      before { setup_email_config(smtp_enabled: true, smtp_username: '') }

      it 'falls back to contact_email when username is blank' do
        expect_from_address('contact@example.com')
      end
    end

    context 'real-world email alignment scenarios' do
      it 'prevents Gmail/domain mismatch issues' do
        # Simulate the original problematic configuration
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'donotreply.vulcan@gmail.com',
          contact_email: 'saf@mitre.org'
        )

        # Should use SMTP username to prevent authentication mismatch
        expect_from_address('donotreply.vulcan@gmail.com')
      end

      it 'works correctly with professional email services' do
        # Simulate proper Mailgun/SendGrid setup
        setup_email_config(
          smtp_enabled: true,
          smtp_username: 'support@company.com',
          contact_email: 'support@company.com'
        )

        expect_from_address('support@company.com')
      end
    end
  end
end
