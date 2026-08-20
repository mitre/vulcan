# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Classification Banner' do
  # Settings is a process-wide singleton. Every key a context mutates MUST be
  # restored to its ORIGINAL value afterward — a partial restore leaks the
  # mutation into whichever spec the parallel worker runs next (found live: a
  # String consent version from this file failing the Settings-defaults type
  # pins under example randomization). Originals are captured, never
  # hardcoded, so a yml default change cannot silently diverge from the
  # restore.
  def override_settings(section, overrides)
    originals = overrides.keys.index_with { |key| section[key] }
    overrides.each { |key, value| section[key] = value }
    originals
  end

  def restore_settings(section, originals)
    originals.each { |key, value| section[key] = value }
  end

  before do
    Rails.application.reload_routes!
  end

  # The banner is rendered in the application layout, so any page that uses it will show it.
  # The login page (root when not signed in) is the simplest to test.

  context 'when banner is enabled' do
    before do
      @banner_originals = override_settings(
        Settings.banner,
        'enabled' => true, 'text' => 'UNCLASSIFIED',
        'background_color' => '#007a33', 'text_color' => '#ffffff'
      )
    end

    after { restore_settings(Settings.banner, @banner_originals) }

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
    before { @banner_originals = override_settings(Settings.banner, 'enabled' => false) }

    after { restore_settings(Settings.banner, @banner_originals) }

    it 'does not render the banner' do
      get new_user_session_path
      expect(response.body).not_to include('classification-banner')
    end
  end

  context 'when banner is enabled but text is blank' do
    before do
      @banner_originals = override_settings(Settings.banner, 'enabled' => true, 'text' => '')
    end

    after { restore_settings(Settings.banner, @banner_originals) }

    it 'does not render the banner' do
      get new_user_session_path
      expect(response.body).not_to include('classification-banner')
    end
  end

  context 'consent config is passed to navbar' do
    before do
      @consent_originals = override_settings(
        Settings.consent,
        'enabled' => true, 'version' => 2,
        'title' => 'Accept Terms', 'content' => 'You must agree.'
      )
    end

    after { restore_settings(Settings.consent, @consent_originals) }

    it 'includes consent config JSON in the navbar element' do
      get new_user_session_path
      expect(response.body).to include('consent_config')
    end
  end
end
