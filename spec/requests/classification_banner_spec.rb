# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Classification Banner' do
  before do
    Rails.application.reload_routes!
  end

  # The banner is rendered in the application layout, so any page that uses it will show it.
  # The login page (root when not signed in) is the simplest to test.

  context 'when banner is enabled' do
    before do
      Settings.banner['enabled'] = true
      Settings.banner['text'] = 'UNCLASSIFIED'
      Settings.banner['background_color'] = '#007a33'
      Settings.banner['text_color'] = '#ffffff'
    end

    after do
      Settings.banner['enabled'] = false
      Settings.banner['text'] = ''
    end

    it 'renders the banner text at top and bottom' do
      get new_user_session_path
      expect(response.body).to include('UNCLASSIFIED')
      expect(response.body.scan('classification-banner').size).to be >= 2
    end

    it 'applies the configured background and text colors' do
      get new_user_session_path
      expect(response.body).to include('background-color: #007a33')
      expect(response.body).to include('color: #ffffff')
    end

    it 'renders the bottom banner with fixed positioning class' do
      get new_user_session_path
      expect(response.body).to include('classification-banner--bottom')
    end
  end

  context 'when banner is disabled' do
    before do
      Settings.banner['enabled'] = false
    end

    it 'does not render the banner' do
      get new_user_session_path
      expect(response.body).not_to include('classification-banner')
    end
  end

  context 'when banner is enabled but text is blank' do
    before do
      Settings.banner['enabled'] = true
      Settings.banner['text'] = ''
    end

    after do
      Settings.banner['enabled'] = false
    end

    it 'does not render the banner' do
      get new_user_session_path
      expect(response.body).not_to include('classification-banner')
    end
  end

  context 'consent config is passed to navbar' do
    before do
      Settings.consent['enabled'] = true
      Settings.consent['version'] = '2'
      Settings.consent['title'] = 'Accept Terms'
      Settings.consent['content'] = 'You must agree.'
    end

    after do
      Settings.consent['enabled'] = false
    end

    it 'includes consent config JSON in the navbar element' do
      get new_user_session_path
      expect(response.body).to include('consent_config')
    end
  end
end
