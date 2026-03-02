# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'release infrastructure' do
  # REQUIREMENT: The release process must be automated via release-please.
  # Version must be consistent across all sources. Docker builds trigger
  # on published GitHub releases (handled by ci.yml).

  describe 'release-please configuration' do
    it 'release-please-config.json exists and is valid JSON' do
      config_path = Rails.root.join('release-please-config.json')
      expect(config_path).to exist
      config = JSON.parse(config_path.read)
      expect(config).to have_key('packages')
    end

    it '.release-please-manifest.json exists with current version' do
      manifest_path = Rails.root.join('.release-please-manifest.json')
      expect(manifest_path).to exist
      manifest = JSON.parse(manifest_path.read)
      expect(manifest['.']).to eq(Vulcan::VERSION)
    end

    it 'release workflow exists and uses release-please-action' do
      workflow = Rails.root.join('.github/workflows/release.yml')
      expect(workflow).to exist
      content = workflow.read
      expect(content).to include('googleapis/release-please-action')
    end
  end

  describe 'version consistency' do
    it 'VERSION file, package.json, manifest, and Vulcan::VERSION all match' do
      version_file = Rails.root.join('VERSION').read.strip.delete_prefix('v')
      package_json = JSON.parse(Rails.root.join('package.json').read)['version']
      manifest = JSON.parse(Rails.root.join('.release-please-manifest.json').read)['.']

      expect(version_file).to eq(Vulcan::VERSION), 'VERSION file mismatch'
      expect(package_json).to eq(Vulcan::VERSION), 'package.json mismatch'
      expect(manifest).to eq(Vulcan::VERSION), '.release-please-manifest.json mismatch'
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
