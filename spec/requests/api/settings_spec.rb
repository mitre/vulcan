# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Settings', type: :request do
  before do
    Rails.application.reload_routes!
  end

  describe 'GET /api/settings' do
    context 'with all banners enabled' do
      before do
        # Mock app banner settings
        allow(Settings).to receive_message_chain(:banner_app, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:banner_app, :text).and_return('DEVELOPMENT')
        allow(Settings).to receive_message_chain(:banner_app, :background_color).and_return('#FFA500')
        allow(Settings).to receive_message_chain(:banner_app, :text_color).and_return('#000000')

        # Mock consent banner settings
        allow(Settings).to receive_message_chain(:banner_consent, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:banner_consent, :version).and_return(2)
        allow(Settings).to receive_message_chain(:banner_consent, :title).and_return('System Warning')
        allow(Settings).to receive_message_chain(:banner_consent, :title_align).and_return('left')
        allow(Settings).to receive_message_chain(:banner_consent, :content).and_return('## Test Banner')
      end

      it 'returns all banner configurations' do
        get '/api/settings'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # App banner
        expect(json['banners']['app']['enabled']).to be true
        expect(json['banners']['app']['text']).to eq('DEVELOPMENT')
        expect(json['banners']['app']['backgroundColor']).to eq('#FFA500')
        expect(json['banners']['app']['textColor']).to eq('#000000')

        # Consent banner
        expect(json['banners']['consent']['enabled']).to be true
        expect(json['banners']['consent']['version']).to eq(2)
        expect(json['banners']['consent']['title']).to eq('System Warning')
        expect(json['banners']['consent']['titleAlign']).to eq('left')
        expect(json['banners']['consent']['content']).to eq('## Test Banner')
      end

      it 'does not require authentication' do
        get '/api/settings'

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with default settings' do
      before do
        allow(Settings).to receive(:banner_app).and_return(nil)
        allow(Settings).to receive(:banner_consent).and_return(nil)
      end

      it 'returns default values' do
        get '/api/settings'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # App banner defaults
        expect(json['banners']['app']['enabled']).to be false
        expect(json['banners']['app']['text']).to eq('')
        expect(json['banners']['app']['backgroundColor']).to eq('#198754')
        expect(json['banners']['app']['textColor']).to eq('#ffffff')

        # Consent banner defaults
        expect(json['banners']['consent']['enabled']).to be false
        expect(json['banners']['consent']['version']).to eq(1)
        expect(json['banners']['consent']['title']).to eq('Terms of Use')
        expect(json['banners']['consent']['titleAlign']).to eq('center')
        expect(json['banners']['consent']['content']).to eq('')
      end
    end
  end

  describe 'GET /api/settings/consent_banner' do
    context 'when consent banner is enabled' do
      before do
        allow(Settings).to receive_message_chain(:banner_consent, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:banner_consent, :version).and_return(2)
        allow(Settings).to receive_message_chain(:banner_consent, :title).and_return('System Warning')
        allow(Settings).to receive_message_chain(:banner_consent, :title_align).and_return('left')
        allow(Settings).to receive_message_chain(:banner_consent, :content).and_return('## Test Banner')
      end

      it 'returns consent banner configuration' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be true
        expect(json['version']).to eq(2)
        expect(json['title']).to eq('System Warning')
        expect(json['titleAlign']).to eq('left')
        expect(json['content']).to eq('## Test Banner')
      end

      it 'does not require authentication' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when consent banner is disabled' do
      before do
        allow(Settings).to receive_message_chain(:banner_consent, :enabled).and_return(false)
        allow(Settings).to receive_message_chain(:banner_consent, :version).and_return(1)
        allow(Settings).to receive_message_chain(:banner_consent, :title).and_return('Terms of Use')
        allow(Settings).to receive_message_chain(:banner_consent, :title_align).and_return('center')
        allow(Settings).to receive_message_chain(:banner_consent, :content).and_return('')
      end

      it 'returns disabled configuration' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be false
        expect(json['version']).to eq(1)
        expect(json['title']).to eq('Terms of Use')
        expect(json['titleAlign']).to eq('center')
        expect(json['content']).to eq('')
      end
    end

    context 'when banner_consent setting is nil' do
      before do
        allow(Settings).to receive(:banner_consent).and_return(nil)
      end

      it 'returns default values' do
        get '/api/settings/consent_banner'

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['enabled']).to be false
        expect(json['version']).to eq(1)
        expect(json['title']).to eq('Terms of Use')
        expect(json['titleAlign']).to eq('center')
        expect(json['content']).to eq('')
      end
    end

    context 'with markdown content' do
      before do
        allow(Settings).to receive_message_chain(:banner_consent, :enabled).and_return(true)
        allow(Settings).to receive_message_chain(:banner_consent, :version).and_return(1)
        allow(Settings).to receive_message_chain(:banner_consent, :title).and_return('Terms of Use')
        allow(Settings).to receive_message_chain(:banner_consent, :title_align).and_return('center')
        allow(Settings).to receive_message_chain(:banner_consent, :content).and_return(
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
