# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'release infrastructure' do
  # Releases are created manually via the GitHub UI.
  # Version must be consistent across all sources. Docker builds trigger
  # on published GitHub releases (handled by release.yml).

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
    it 'release.yml triggers docker-release on published releases' do
      release = Rails.root.join('.github/workflows/release.yml').read
      expect(release).to match(/release:.*\n.*types:.*published/m),
                         'release.yml must trigger on release published events for Docker builds'
    end
  end

  # README.md's `docker pull` line carried `mitre/vulcan:v2.4.2` for two
  # releases. No workflow has ever pushed a "v"-prefixed tag: release.yml
  # strips the prefix (`version=${raw#v}`) before handing TAG_SUFFIXES to bake,
  # and mainline.yml pushes the git sha plus `latest`. A reader following the
  # README got "manifest unknown". Nothing pinned that line, so it rotted
  # silently every release.
  #
  # The guard derives the forbidden shape from the workflow instead of from a
  # hardcoded tag, and covers the pages that instruct a reader to pull or run
  # an image: the README and the deployment/getting-started trees. The
  # maintainer-facing release runbook is excluded because it documents the
  # workflow's own inputs rather than telling an operator what to pull.
  describe 'documented image tags' do
    let(:install_facing_docs) do
      [
        'README.md',
        'docs/site/index.md',
        'docs/site/getting-started/**/*.md',
        'docs/site/deployment/**/*.md'
      ]
    end

    it 'release.yml still strips the leading "v" before tagging the image' do
      release = Rails.root.join('.github/workflows/release.yml').read
      expect(release).to include('version=${raw#v}'),
                         'release.yml no longer strips the "v" prefix — if released tags are now ' \
                         'v-prefixed, this guard and the install docs both need updating.'
    end

    it 'no install-facing page tells a reader to pull a v-prefixed tag' do
      offenders = install_facing_docs.flat_map { |glob| Rails.root.glob(glob) }
                                     .uniq
                                     .reject { |path| path.basename.to_s == 'release-process.md' }
                                     .flat_map do |path|
        relative = path.relative_path_from(Rails.root)
        path.read.lines.each_with_index.filter_map do |line, index|
          "#{relative}:#{index + 1}: #{line.strip}" if line.match?(%r{mitre/vulcan:v\d})
        end
      end

      expect(offenders).to eq([]),
                           'these pages reference an image tag no workflow publishes — released ' \
                           'tags have no "v" prefix (use mitre/vulcan:release-latest, or ' \
                           "mitre/vulcan:<x.y.z> to pin):\n#{offenders.join("\n")}"
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
