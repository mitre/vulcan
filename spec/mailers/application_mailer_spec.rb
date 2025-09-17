# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'default from address' do
    let(:mailer) { ApplicationMailer.new }

    context 'when SMTP is disabled' do
      before do
        allow(Settings.smtp).to receive(:enabled).and_return(false)
        allow(Settings).to receive(:contact_email).and_return('contact@example.com')
      end

      it 'uses contact_email as from address' do
        from_address = mailer.default_params[:from].call
        expect(from_address).to eq('contact@example.com')
      end
    end

    context 'when SMTP is enabled but no username configured' do
      before do
        allow(Settings.smtp).to receive_messages(enabled: true, settings: {})
        allow(Settings).to receive(:contact_email).and_return('contact@example.com')
      end

      it 'falls back to contact_email' do
        from_address = mailer.default_params[:from].call
        expect(from_address).to eq('contact@example.com')
      end
    end

    context 'when SMTP is enabled with username configured' do
      before do
        allow(Settings.smtp).to receive_messages(
          enabled: true,
          settings: { 'user_name' => 'smtp-user@mailserver.com' }
        )
        allow(Settings).to receive(:contact_email).and_return('contact@example.com')
      end

      it 'uses SMTP username as from address for authentication alignment' do
        from_address = mailer.default_params[:from].call
        expect(from_address).to eq('smtp-user@mailserver.com')
      end
    end

    context 'when SMTP is enabled with blank username' do
      before do
        allow(Settings.smtp).to receive_messages(
          enabled: true,
          settings: { 'user_name' => '' }
        )
        allow(Settings).to receive(:contact_email).and_return('contact@example.com')
      end

      it 'falls back to contact_email when username is blank' do
        from_address = mailer.default_params[:from].call
        expect(from_address).to eq('contact@example.com')
      end
    end

    context 'real-world email alignment scenarios' do
      it 'prevents Gmail/domain mismatch issues' do
        # Simulate the original problematic configuration
        allow(Settings.smtp).to receive_messages(
          enabled: true,
          settings: { 'user_name' => 'donotreply.vulcan@gmail.com' }
        )
        allow(Settings).to receive(:contact_email).and_return('saf@mitre.org')

        from_address = mailer.default_params[:from].call
        # Should use SMTP username to prevent authentication mismatch
        expect(from_address).to eq('donotreply.vulcan@gmail.com')
      end

      it 'works correctly with professional email services' do
        # Simulate proper Mailgun/SendGrid setup
        allow(Settings.smtp).to receive_messages(
          enabled: true,
          settings: { 'user_name' => 'support@company.com' }
        )
        allow(Settings).to receive(:contact_email).and_return('support@company.com')

        from_address = mailer.default_params[:from].call
        expect(from_address).to eq('support@company.com')
      end
    end
  end
end
