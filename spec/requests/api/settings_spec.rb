# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Settings', type: :request do
  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/settings/consent_banner' do
    context 'when consent banner is enabled' do
      before do
        allow(Settings).to receive_message_chain(:consent_banner, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:consent_banner, :version).and_return(2)
        allow(Settings).to receive_message_chain(:consent_banner, :content).and_return('## Test Banner')
      end

      it 'returns consent banner configuration' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be true
        expect(json['version']).to eq(2)
        expect(json['content']).to eq('## Test Banner')
      end

      it 'does not require authentication' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when consent banner is disabled' do
      before do
        allow(Settings).to receive_message_chain(:consent_banner, :enabled).and_return(false)
        allow(Settings).to receive_message_chain(:consent_banner, :version).and_return(1)
        allow(Settings).to receive_message_chain(:consent_banner, :content).and_return('')
      end

      it 'returns disabled configuration' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be false
        expect(json['version']).to eq(1)
        expect(json['content']).to eq('')
      end
    end

    context 'when consent_banner setting is nil' do
      before do
        allow(Settings).to receive(:consent_banner).and_return(nil)
      end

      it 'returns default values' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be false
        expect(json['version']).to eq(1)
        expect(json['content']).to eq('')
      end
    end

    context 'with markdown content' do
      before do
        allow(Settings).to receive_message_chain(:consent_banner, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:consent_banner, :version).and_return(1)
        allow(Settings).to receive_message_chain(:consent_banner, :content).and_return(
          "## System Access\n\n- Item 1\n- Item 2"
        )
      end

      it 'returns markdown content unchanged' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['content']).to include('## System Access')
        expect(json['content']).to include('- Item 1')
      end
    end
  end
end
