# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer do
  describe 'default from address' do
    let(:mailer) { ApplicationMailer.new }
    let(:from_address) { mailer.default_params[:from].call }

    it 'always uses Settings.contact_email following community standard' do
      allow(Settings).to receive(:contact_email).and_return('support@example.com')

      expect(from_address).to eq('support@example.com')
    end

    it 'works with different contact email values' do
      allow(Settings).to receive(:contact_email).and_return('notifications@company.org')

      expect(from_address).to eq('notifications@company.org')
    end

    it 'handles nil contact_email gracefully with fallback' do
      allow(Settings).to receive(:contact_email).and_return(nil)

      expect(from_address).to eq('vulcan-support@example.com')
    end
  end
end
