# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'zip'
require 'stringio'

RSpec.describe 'sync rake tasks' do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:runner) { Import::JsonArchive::Merge::SyncRakeRunner.new(stdout, stderr) }

  let(:component) { create(:component, :closed_comment_phase) }

  # Stable tmpdir for the example — survives until the after-block sweeps.
  let(:tmpdir) { Dir.mktmpdir('sync_spec') }

  after { FileUtils.rm_rf(tmpdir) }

  # Build a backup zip from a component on the fly. Mirrors
  # Export::Formatters::JsonArchiveFormatter#generate_from_component
  # but skips the eager-loading dance — tiny test components.
  def write_zip_from(component, name: SecureRandom.hex(4), mutations: nil)
    data = Export::Serializers::BackupSerializer.new(component).serialize
    mutations&.call(data)
    manifest = { backup_format_version: '1.1', vulcan_version: 'test', components: [] }

    path = File.join(tmpdir, "#{name}.zip")
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('manifest.json') { |s| s.write(manifest.to_json) }
      zip.get_output_stream('component.json') { |s| s.write(data[:component].to_json) }
      zip.get_output_stream('rules.json') { |s| s.write(data[:rules].to_json) }
      zip.get_output_stream('satisfactions.json') { |s| s.write(data[:satisfactions].to_json) }
      zip.get_output_stream('reviews.json') { |s| s.write(data[:reviews].to_json) }
    end
    path
  end

  describe '#diff (SyncRakeRunner)' do
    it 'exits 0 on identical archives (no conflicts, all matched)' do
      path = write_zip_from(component)
      code = runner.diff(ours_path: path, theirs_path: path)

      expect(code).to eq(0)
      expect(stdout.string).to include('=== Merge Plan ===')
      expect(stdout.string).to match(/rules:.*matched=#{component.rules.count}/)
      expect(stdout.string).to include('only_ours=0')
      expect(stdout.string).to include('only_theirs=0')
    end

    it 'reports field changes when one rule diverges' do
      ours_path = write_zip_from(component)
      theirs_path = write_zip_from(component, mutations: ->(d) { d[:rules].first[:fixtext] = 'THEIRS edited' })

      code = runner.diff(ours_path: ours_path, theirs_path: theirs_path)

      # Strategy default for fixtext is :conflict; this is the locked-field
      # exit-1 contract but for a non-locked field that defaults to conflict.
      expect(code).to eq(1)
      expect(stdout.string).to include('fixtext')
      expect(stdout.string).to include('THEIRS edited')
    end

    it 'exits 2 with a stderr message when zip file is missing' do
      code = runner.diff(ours_path: '/tmp/no-such-file.zip', theirs_path: '/tmp/also-missing.zip')

      expect(code).to eq(2)
      expect(stderr.string).to include('sync:diff:')
    end
  end

  describe '#preview (SyncRakeRunner)' do
    it 'compares an archive against the live DB and exits 0 when matched' do
      path = write_zip_from(component)

      code = runner.preview(component_id: component.id, theirs_path: path)

      expect(code).to eq(0)
      expect(stdout.string).to include('=== Merge Plan ===')
      expect(stdout.string).to match(/rules:.*matched=#{component.rules.count}/)
    end

    it 'exits 2 when component_id is unknown' do
      path = write_zip_from(component)

      code = runner.preview(component_id: 0, theirs_path: path)

      expect(code).to eq(2)
      expect(stderr.string).to include('sync:preview:')
    end

    it 'exits 2 with stderr when receiving component has open comment_phase' do
      open_component = create(:component, :open_comment_period)
      path = write_zip_from(component) # any valid archive

      code = runner.preview(component_id: open_component.id, theirs_path: path)

      expect(code).to eq(2)
      expect(stderr.string).to include('Precondition failed')
    end
  end

  describe 'rake task wiring' do
    before(:all) do
      Rails.application.load_tasks unless Rake::Task.task_defined?('sync:diff')
    end

    it 'sync:diff is a registered task' do
      expect(Rake::Task.task_defined?('sync:diff')).to be(true)
    end

    it 'sync:preview is a registered task' do
      expect(Rake::Task.task_defined?('sync:preview')).to be(true)
    end
  end
end
