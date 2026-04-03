# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Production mailer configuration' do
  it 'does not hardcode example.com as mailer host' do
    bad_lines = grep_config('config/environments/production.rb', /host:\s*['"]example\.com['"]/)

    expect(bad_lines).to be_empty,
                         "production.rb hardcodes example.com as mailer host:\n#{bad_lines.map(&:strip).join("\n")}"
  end
end
