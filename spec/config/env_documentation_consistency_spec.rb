# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ENV documentation consistency' do
  let(:env_vars_md) { Rails.root.join('ENVIRONMENT_VARIABLES.md').read }
  let(:github_docs) { Rails.root.join('docs/deployment/auth/github.md').read }

  it 'ENVIRONMENT_VARIABLES.md GitHub vars match what devise.rb uses (no VULCAN_ prefix)' do
    expect(env_vars_md).to include('GITHUB_APP_ID'),
                           'ENVIRONMENT_VARIABLES.md should reference GITHUB_APP_ID (no VULCAN_ prefix)'
    expect(env_vars_md).not_to include('VULCAN_GITHUB_APP_ID'),
                               'ENVIRONMENT_VARIABLES.md should NOT reference VULCAN_GITHUB_APP_ID'
  end

  it 'deployment docs do not reference incorrect VULCAN_GITHUB_ variable names' do
    expect(github_docs).not_to include('VULCAN_GITHUB_APP_ID'),
                               'github.md should use GITHUB_APP_ID (matching devise.rb)'
    expect(github_docs).not_to include('VULCAN_GITHUB_APP_SECRET'),
                               'github.md should use GITHUB_APP_SECRET (matching devise.rb)'
  end
end
