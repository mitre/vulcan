# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'database.yml password safety' do
  # database.yml uses ENV.fetch('POSTGRES_PASSWORD', 'postgres') in the default block.
  # This works correctly because:
  # - Docker: POSTGRES_PASSWORD is set via .env or environment → uses Docker password
  # - Local without .env: ENV var is unset → falls back to 'postgres'
  #
  # The key requirement is that the default fallback exists so local dev works
  # without any .env file present.

  let(:db_config) { Rails.root.join('config/database.yml').read }

  it 'default block has a fallback password for local development' do
    default_section = db_config[/^default:.*?(?=^\w|\z)/m]
    password_line = default_section.lines.find { |l| l.strip.start_with?('password:') }
    expect(password_line).not_to be_nil, 'default block must have a password: line'
    expect(password_line).to match(/ENV.fetch.*postgres/),
                             'password must use ENV.fetch with a postgres fallback for local dev'
  end

  it 'production block does not hardcode a password' do
    prod_section = db_config[/^production:.*?(?=^\w|\z)/m]
    prod_password_line = prod_section.to_s.lines.find { |l| l.strip.start_with?('password:') && l.exclude?('ENV') }
    expect(prod_password_line).to be_nil,
                                  'production must not hardcode a password (use ENV or DATABASE_URL)'
  end
end
