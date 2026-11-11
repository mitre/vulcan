# frozen_string_literal: true

require 'rails_helper'
require 'tomlrb'
require 'open3'

##
# One toolchain, pinned once.
#
# Developers and CI install Ruby, Node and Yarn with mise, which reads the
# versions from .ruby-version, .nvmrc and package.json's packageManager and
# records the exact release and its checksums in mise.lock. The container image
# cannot use mise for Ruby: it compiles Ruby from source against the base
# image's OpenSSL (see the Dockerfile), so it pins its own versions and
# checksums as build arguments. Heroku reads only package.json's engines.node.
#
# Every one of those pins must name the same release mise.lock records, or the
# image and Heroku build with a different toolchain than the one tested. The
# lock is read here, never hardcoded, so a version bump needs no edit to this
# spec; it fails until every pin moves with the lock.
RSpec.describe 'Toolchain version consistency' do
  def lock
    @lock ||= Tomlrb.load_file(Rails.root.join('mise.lock').to_s)
  end

  # The single locked entry for a tool. Ruby has one entry per install mode
  # (prebuilt, compiled, Windows), all naming the same version.
  def locked_version(tool)
    versions = lock.fetch('tools').fetch(tool).map { |entry| entry.fetch('version') }.uniq
    expect(versions.size).to eq(1), "mise.lock records #{tool} versions #{versions.inspect}; expected one"
    versions.first
  end

  def locked_platform(tool, platform)
    lock.fetch('tools').fetch(tool).filter_map { |entry| entry["platforms.#{platform}"] }.first ||
      raise("mise.lock has no #{platform} entry for #{tool}")
  end

  def sha256(platform_entry)
    platform_entry.fetch('checksum').delete_prefix('sha256:')
  end

  # Default values of the Dockerfile's top-level build arguments.
  def dockerfile_args
    @dockerfile_args ||= Rails.root.join('Dockerfile').read
                              .scan(/^ARG ([A-Z0-9_]+)=(\S+)$/).to_h
  end

  def dockerfile
    @dockerfile ||= Rails.root.join('Dockerfile').read
  end

  def bake_default(variable)
    Rails.root.join('docker-bake.hcl').read[/variable "#{variable}" \{\s*default = "([^"]+)"/, 1]
  end

  def package_json
    @package_json ||= JSON.parse(Rails.root.join('package.json').read)
  end

  describe 'mise' do
    it 'is the release CI installs, which mise.toml requires' do
      min_version = Tomlrb.load_file(Rails.root.join('mise.toml').to_s).fetch('min_version')
      action = YAML.safe_load_file(Rails.root.join('.github/actions/setup-toolchain/action.yml'))
      mise_step = action.dig('runs', 'steps').find { |step| step['uses'].to_s.start_with?('jdx/mise-action@') }
      expect(mise_step.dig('with', 'version').to_s).to eq(min_version)
    end
  end

  describe 'Ruby' do
    let(:version) { locked_version('ruby') }

    it 'matches .ruby-version' do
      expect(Rails.root.join('.ruby-version').read.strip).to eq(version)
    end

    it 'is the Ruby Heroku installs, from Gemfile.lock' do
      expect(Rails.root.join('Gemfile.lock').read[/^RUBY VERSION\n\s+ruby (\d+\.\d+\.\d+)/, 1]).to eq(version)
    end

    it "is the Gemfile's ruby requirement" do
      expect(Rails.root.join('Gemfile').read[/^ruby ['"]([^'"]+)['"]/, 1]).to eq(version)
    end

    it 'is the version the image compiles' do
      expect(dockerfile_args['RUBY_VERSION']).to eq(version)
      expect(bake_default('VULCAN_RUBY_VERSION')).to eq(version)
    end

    it 'verifies the source tarball against the checksum mise.lock records for it' do
      tarball = "https://cache.ruby-lang.org/pub/ruby/#{version[/\A\d+\.\d+/]}/ruby-#{version}.tar.gz"
      source = lock.fetch('tools').fetch('ruby')
                   .flat_map { |entry| entry.select { |key, _| key.start_with?('platforms.') }.values }
                   .find { |platform| platform['url'] == tarball }
      expect(source).not_to be_nil, "mise.lock records no checksum for #{tarball}"
      expect(dockerfile_args['RUBY_SHA256']).to eq(sha256(source))
    end
  end

  describe 'Node' do
    let(:version) { locked_version('node') }
    let(:major) { version.split('.').first }

    it 'is on the release line .nvmrc names' do
      expect(Rails.root.join('.nvmrc').read.strip).to eq(major)
    end

    it 'gives Heroku the same release line through engines.node' do
      expect(package_json.dig('engines', 'node')).to eq("#{major}.x")
    end

    it 'is the release the image installs' do
      expect(dockerfile_args['NODE_VERSION']).to eq(version)
      expect(bake_default('VULCAN_NODE_VERSION')).to eq(version)
    end

    it 'verifies each image architecture against the checksum mise.lock records' do
      { 'amd64' => 'linux-x64', 'arm64' => 'linux-arm64' }.each do |docker_arch, platform|
        locked = locked_platform('node', platform)
        expect(locked['url']).to eq("https://nodejs.org/dist/v#{version}/node-v#{version}-#{platform}.tar.gz")
        arg = "NODE_SHA256_#{docker_arch.upcase}"
        expect(dockerfile_args[arg]).to eq(sha256(locked)), "#{arg} does not match mise.lock's #{platform} checksum"
      end
    end
  end

  describe 'Yarn' do
    let(:version) { locked_version('yarn') }

    it 'is the packageManager release' do
      expect(package_json['packageManager']).to eq("yarn@#{version}")
    end

    it 'is the release the image installs, verified against mise.lock' do
      expect(dockerfile_args['YARNPKG_VERSION']).to eq(version)
      %w[linux-x64 linux-arm64].each do |platform|
        locked = locked_platform('yarn', platform)
        expect(locked['url']).to eq("https://repo.yarnpkg.com/#{version}/packages/yarnpkg-cli/bin/yarn.js")
        expect(dockerfile_args['YARNPKG_SHA256']).to eq(sha256(locked)), "YARNPKG_SHA256 does not match #{platform}"
      end
    end

    # Yarn reads every YARN_* environment variable as a setting and refuses to
    # run on one it does not know, and build arguments reach the environment of
    # every RUN in their stage and the stages built from it.
    it 'declares no build argument Yarn would read as a setting' do
      expect(Rails.root.join('Dockerfile').read.scan(/^ARG (YARN_\w*)/).flatten).to be_empty
    end

    it 'runs through the bin/yarn binstub' do
      output, status = Open3.capture2e(Rails.root.join('bin/yarn').to_s, '--version')
      expect(status).to be_success, output
      expect(output.strip).to eq(version)
    end

    it 'is not fetched unverified through corepack' do
      expect(dockerfile).not_to match(/^\s*[^#\n]*\bcorepack\b/)
    end

    it 'installs dependencies from the lockfile without changing it, as CI does' do
      installs = dockerfile.scan(/^[^#\n]*\byarn install\b.*$/)
      expect(installs).not_to be_empty
      expect(installs).to all(include('--immutable'))
      expect(dockerfile).not_to include('--frozen-lockfile')
    end
  end
end
