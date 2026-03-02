# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'No redundant ENV fallbacks' do
  it 'controllers do not re-read VULCAN_OIDC ENV vars directly' do
    matches = grep_ruby_dir('app/controllers', /ENV(?:\.fetch\(|\[)['"]VULCAN_OIDC_/)

    expect(matches).to be_empty,
                       "Controllers should use Settings, not ENV, for OIDC config:\n#{matches.join("\n")}"
  end
end
