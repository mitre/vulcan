# frozen_string_literal: true

require 'rails_helper'
require 'climate_control'

# The settings template interpolates env vars into YAML with ERB. A value
# whose first character is `#` (Slack channels, hex colors, passwords)
# renders as a YAML comment when the interpolation is unquoted — the value
# silently becomes nil and, where an initializer backstop exists, gets
# replaced by the default instead of the deployer's chosen value. These
# tests render the template exactly as Settingslogic does and pin that
# YAML-special characters survive the trip.
RSpec.describe 'config/vulcan.default.yml template rendering' do
  def rendered_defaults
    raw = ERB.new(Rails.root.join('config/vulcan.default.yml').read).result
    YAML.safe_load(raw, permitted_classes: [Symbol], aliases: true)['defaults']
  end

  it 'keeps a hash-leading slack channel id' do
    ClimateControl.modify(VULCAN_SLACK_CHANNEL_ID: '#vulcan-test') do
      expect(rendered_defaults.dig('slack', 'channel_id')).to eq('#vulcan-test')
    end
  end

  it 'keeps a hash-leading custom banner color' do
    ClimateControl.modify(VULCAN_BANNER_BACKGROUND_COLOR: '#ff0000') do
      expect(rendered_defaults.dig('banner', 'background_color')).to eq('#ff0000')
    end
  end

  it 'keeps an smtp password full of YAML-special characters' do
    ClimateControl.modify(VULCAN_SMTP_SERVER_PASSWORD: '#p@ss: {word}') do
      expect(rendered_defaults.dig('smtp', 'settings', 'password')).to eq('#p@ss: {word}')
    end
  end

  it 'keeps a hash-leading oidc client secret' do
    ClimateControl.modify(VULCAN_OIDC_CLIENT_SECRET: '#secret#') do
      expect(rendered_defaults.dig('oidc', 'args', 'client_options', 'secret')).to eq('#secret#')
    end
  end

  it 'renders the documented defaults when env vars are unset' do
    ClimateControl.modify(VULCAN_SLACK_CHANNEL_ID: nil, VULCAN_BANNER_BACKGROUND_COLOR: nil,
                          VULCAN_BANNER_TEXT_COLOR: nil, VULCAN_WELCOME_TEXT: nil) do
      defaults = rendered_defaults
      expect(defaults.dig('slack', 'channel_id')).to be_nil
      expect(defaults.dig('banner', 'background_color')).to eq('#007a33')
      expect(defaults.dig('banner', 'text_color')).to eq('#ffffff')
      expect(defaults['welcome_text']).to eq('Welcome to Vulcan')
    end
  end
end
