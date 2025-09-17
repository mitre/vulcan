# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SMTP Settings Initializer' do
  let(:original_env) { Rails.env }

  before do
    # Reset ActionMailer settings
    ActionMailer::Base.smtp_settings = {}
  end

  after do
    # Restore original environment
    allow(Rails).to receive(:env).and_return(original_env)
    ActionMailer::Base.smtp_settings = {}
  end

  context 'in production environment' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    end

    context 'when SMTP is enabled' do
      before do
        allow(Settings.smtp).to receive(:enabled).and_return(true)
        allow(Settings.smtp).to receive(:settings).and_return({
          'address' => 'smtp.example.com',
          'port' => 587,
          'authentication' => 'plain'
        })
        allow(Settings).to receive(:contact_email).and_return('default@example.com')
      end

      it 'defaults SMTP username to contact_email when not configured' do
        # Reload the initializer
        load Rails.root.join('config/initializers/smtp_settings.rb')

        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('default@example.com')
      end

      it 'preserves explicit SMTP username when configured' do
        allow(Settings.smtp).to receive(:settings).and_return({
          'address' => 'smtp.example.com',
          'port' => 587,
          'authentication' => 'plain',
          'user_name' => 'explicit@example.com'
        })

        # Reload the initializer
        load Rails.root.join('config/initializers/smtp_settings.rb')

        expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('explicit@example.com')
      end

      it 'configures ActionMailer correctly' do
        # Reload the initializer
        load Rails.root.join('config/initializers/smtp_settings.rb')

        expect(ActionMailer::Base.delivery_method).to eq(:smtp)
        expect(Rails.application.config.action_mailer.delivery_method).to eq(:smtp)
        expect(Rails.application.config.action_mailer.perform_deliveries).to be(true)
        expect(Rails.application.config.action_mailer.raise_delivery_errors).to be(true)
      end
    end

    context 'when SMTP is disabled' do
      before do
        allow(Settings.smtp).to receive(:enabled).and_return(false)
      end

      it 'does not configure SMTP settings' do
        original_delivery_method = ActionMailer::Base.delivery_method

        # Reload the initializer
        load Rails.root.join('config/initializers/smtp_settings.rb')

        expect(ActionMailer::Base.delivery_method).to eq(original_delivery_method)
        expect(ActionMailer::Base.smtp_settings).to be_empty
      end
    end
  end

  context 'in non-production environments' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(Settings.smtp).to receive(:enabled).and_return(true)
    end

    it 'does not configure SMTP settings' do
      original_delivery_method = ActionMailer::Base.delivery_method

      # Reload the initializer
      load Rails.root.join('config/initializers/smtp_settings.rb')

      expect(ActionMailer::Base.delivery_method).to eq(original_delivery_method)
    end
  end

  describe 'email configuration simplification' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(Settings.smtp).to receive(:enabled).and_return(true)
    end

    it 'supports simple deployment with just contact_email' do
      # Simulate simple deployment: only contact_email set
      allow(Settings.smtp).to receive(:settings).and_return({
        'address' => 'smtp.mailgun.org',
        'port' => 587,
        'authentication' => 'plain'
        # No user_name configured
      })
      allow(Settings).to receive(:contact_email).and_return('support@myapp.com')

      # Reload the initializer
      load Rails.root.join('config/initializers/smtp_settings.rb')

      # Should automatically use contact_email for SMTP authentication
      expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('support@myapp.com')
    end

    it 'supports complex deployment with separate SMTP username' do
      # Simulate complex deployment: different SMTP username
      allow(Settings.smtp).to receive(:settings).and_return({
        'address' => 'smtp.sendgrid.net',
        'port' => 587,
        'authentication' => 'plain',
        'user_name' => 'apikey'  # SendGrid uses 'apikey' as username
      })
      allow(Settings).to receive(:contact_email).and_return('support@myapp.com')

      # Reload the initializer
      load Rails.root.join('config/initializers/smtp_settings.rb')

      # Should preserve the explicit SMTP username
      expect(ActionMailer::Base.smtp_settings[:user_name]).to eq('apikey')
    end
  end
end