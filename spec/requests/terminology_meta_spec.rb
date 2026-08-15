# frozen_string_literal: true

require 'rails_helper'

# The application layout emits one meta tag carrying Settings.terminology as
# JSON on every page; constants/terminology.js reads it at module init so a
# deployment's VULCAN_TERM_* env vars rename the entity noun app-wide.
RSpec.describe 'Terminology meta tag' do
  include SettingsEnvHelpers

  before do
    Rails.application.reload_routes!
  end

  def terminology_tags
    Nokogiri::HTML(response.body).css('meta[name="vulcan-terminology"]')
  end

  it 'emits exactly one meta tag with the default terms' do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
    expect(terminology_tags.size).to eq(1)
    terms = JSON.parse(terminology_tags.first['content'])
    expect(terms['stig']).to eq('singular' => 'Rule', 'plural' => 'Rules', 'label' => 'Rule')
    expect(terms['srg']).to eq('singular' => 'Requirement', 'plural' => 'Requirements', 'label' => 'Req')
  end

  it 'carries overridden env values and leaves the other kind at its default' do
    with_settings_env(VULCAN_TERM_SRG_SINGULAR: 'Control', VULCAN_TERM_SRG_PLURAL: 'Controls',
                      VULCAN_TERM_SRG_LABEL: 'Ctrl') do
      get new_user_session_path

      terms = JSON.parse(terminology_tags.first['content'])
      expect(terms['srg']).to eq('singular' => 'Control', 'plural' => 'Controls', 'label' => 'Ctrl')
      expect(terms['stig']).to eq('singular' => 'Rule', 'plural' => 'Rules', 'label' => 'Rule')
    end
  end
end
