# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'release infrastructure' do
  # Releases are created manually via the GitHub UI.
  # Version must be consistent across all sources. Docker builds trigger
  # on published GitHub releases (handled by ci.yml).

  describe 'changelog configuration' do
    it 'cliff.toml exists with Keep a Changelog sections' do
      config_path = Rails.root.join('cliff.toml')
      expect(config_path).to exist
      content = config_path.read
      expect(content).to include('Added')
      expect(content).to include('Fixed')
      expect(content).to include('Keep a Changelog')
    end
  end

  describe 'version consistency' do
    it 'VERSION file, package.json, and Vulcan::VERSION all match' do
      version_file = Rails.root.join('VERSION').read.strip.delete_prefix('v')
      package_json = JSON.parse(Rails.root.join('package.json').read)['version']

      expect(version_file).to eq(Vulcan::VERSION), 'VERSION file mismatch'
      expect(package_json).to eq(Vulcan::VERSION), 'package.json mismatch'
    end
  end

  describe 'Docker release trigger' do
    it 'ci.yml triggers docker-release on published releases' do
      ci = Rails.root.join('.github/workflows/ci.yml').read
      expect(ci).to match(/release:.*\n.*types:.*published/m),
                    'ci.yml must trigger on release published events for Docker builds'
    end
  end

  describe 'API version controller' do
    it 'Api::VersionController exists and skips authentication' do
      expect(defined?(Api::VersionController)).to eq('constant')
      callbacks = Api::VersionController._process_action_callbacks
                                        .select { |cb| cb.kind == :before }
                                        .map(&:filter)
      expect(callbacks).not_to include(:authenticate_user!)
    end
  end
end
