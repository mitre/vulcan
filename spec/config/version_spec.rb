# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'application version' do
  # REQUIREMENT: Version must have a single source of truth in Ruby,
  # accessible from controllers/views, and consistent with VERSION file
  # and package.json.

  describe 'Vulcan::VERSION constant' do
    it 'is defined' do
      expect(defined?(Vulcan::VERSION)).to eq('constant')
    end

    it 'follows semver format' do
      expect(Vulcan::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it 'matches VERSION file (without v prefix)' do
      version_file = Rails.root.join('VERSION').read.strip.delete_prefix('v')
      expect(Vulcan::VERSION).to eq(version_file)
    end

    it 'matches package.json version' do
      package = JSON.parse(Rails.root.join('package.json').read)
      expect(Vulcan::VERSION).to eq(package['version'])
    end
  end

  describe 'Rails config' do
    it 'exposes version via Rails.application.config.vulcan_version' do
      expect(Rails.application.config.vulcan_version).to eq(Vulcan::VERSION)
    end
  end

  describe 'health check config' do
    it 'success message includes version' do
      expect(HealthCheck.success).to include(Vulcan::VERSION)
    end
  end
end
