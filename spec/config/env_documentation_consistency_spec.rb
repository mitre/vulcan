# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ENV documentation consistency' do
  let(:env_vars_md) { Rails.root.join('ENVIRONMENT_VARIABLES.md').read }
  let(:github_docs) { Rails.root.join('docs/site/deployment/auth/github.md').read }

  it 'ENVIRONMENT_VARIABLES.md GitHub vars match what devise.rb uses (no VULCAN_ prefix)' do
    expect(env_vars_md).to include('GITHUB_APP_ID'),
                           'ENVIRONMENT_VARIABLES.md should reference GITHUB_APP_ID (no VULCAN_ prefix)'
    expect(env_vars_md).not_to include('VULCAN_GITHUB_APP_ID'),
                               'ENVIRONMENT_VARIABLES.md should NOT reference VULCAN_GITHUB_APP_ID'
  end

  # testing.md and CONTRIBUTING.md have told contributors to run
  # `COVERAGE=true` since before the harness read it: simplecov_env returned
  # early unless ENV['CI'] was set, so every documented invocation silently
  # produced no report. Both sides of that contract are pinned here.
  describe 'the documented coverage switch' do
    let(:simplecov) { Rails.root.join('spec/simplecov_env.rb').read }
    let(:testing_guide) { Rails.root.join('docs/site/development/testing.md').read }
    let(:contributing) { Rails.root.join('CONTRIBUTING.md').read }

    it 'is read by SimpleCovEnv.start!' do
      expect(simplecov).to include("ENV['COVERAGE']"),
                           'the docs tell contributors to set COVERAGE=true to measure coverage, ' \
                           'so SimpleCovEnv.start! must read it — a documented flag that start! ' \
                           'ignores produces no report at all.'
    end

    it 'is the switch the docs publish' do
      expect(testing_guide).to include('COVERAGE=true'),
                               'docs/site/development/testing.md should publish COVERAGE=true as ' \
                               'the way to measure coverage locally'
      expect(contributing).to include('COVERAGE=true'),
                              'CONTRIBUTING.md should publish COVERAGE=true as the way to ' \
                              'measure coverage locally'
    end
  end

  it 'deployment docs do not reference incorrect VULCAN_GITHUB_ variable names' do
    expect(github_docs).not_to include('VULCAN_GITHUB_APP_ID'),
                               'github.md should use GITHUB_APP_ID (matching devise.rb)'
    expect(github_docs).not_to include('VULCAN_GITHUB_APP_SECRET'),
                               'github.md should use GITHUB_APP_SECRET (matching devise.rb)'
  end
end
