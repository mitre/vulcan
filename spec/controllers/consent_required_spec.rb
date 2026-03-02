# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController do
  # consent_required? must handle corrupted session timestamps gracefully.
  # A corrupted value should trigger re-consent (return true), not a 500.

  controller do
    skip_before_action :authenticate_user!

    def index
      render plain: consent_required?.to_s
    end
  end

  before do
    allow(Settings).to receive(:consent).and_return(
      OpenStruct.new(enabled: true, ttl: '1h')
    )
  end

  context 'when consent_acknowledged_at is a valid timestamp' do
    it 'does not raise' do
      get :index, session: { consent_acknowledged_at: Time.current.iso8601 }
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when consent_acknowledged_at is corrupted' do
    it 'returns true (re-prompt) instead of crashing' do
      get :index, session: { consent_acknowledged_at: 'not-a-timestamp' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('true')
    end
  end

  context 'when consent_acknowledged_at is empty' do
    it 'returns true (re-prompt)' do
      get :index, session: { consent_acknowledged_at: '' }
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('true')
    end
  end
end
