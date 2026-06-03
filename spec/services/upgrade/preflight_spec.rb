# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upgrade::Preflight do
  before { Rails.application.reload_routes! }

  let(:pg_config) do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    { host: config[:host], port: config[:port], user: config[:username], password: config[:password] }
  end

  def pg_conn
    PG.connect(host: pg_config[:host], port: pg_config[:port],
               user: pg_config[:user], password: pg_config[:password], dbname: 'postgres')
  end

  describe '.call' do
    it 'returns a report with required keys' do
      report = described_class.call
      expect(report).to respond_to(:actions)
      expect(report).to respond_to(:warnings)
      expect(report).to respond_to(:blockers)
      expect(report).to respond_to(:current_version)
    end

    it 'returns clean report when nothing to do' do
      report = described_class.call
      expect(report.blockers).to be_empty
    end

    it 'detects legacy database names and reports rename action' do
      conn = pg_conn
      test_old = "vulcan_upgrade_test_old_#{Process.pid}"
      test_new = "vulcan_upgrade_test_new_#{Process.pid}"

      begin
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_old)}")

        manifest = {
          '2.4.0' => {
            'migration_floor' => '20260530010000',
            'required_stop' => true,
            'infrastructure' => [
              { 'type' => 'db_rename', 'from' => test_old, 'to' => test_new }
            ]
          }
        }

        report = described_class.call(manifest_override: manifest)
        rename_actions = report.actions.select { |a| a[:type] == :db_rename }
        expect(rename_actions).to include(
          a_hash_including(type: :db_rename, from: test_old, to: test_new)
        )
      ensure
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_old)}")
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_new)}")
        conn.close
      end
    end

    it 'does not report rename when new name already exists' do
      conn = pg_conn
      test_new = "vulcan_upgrade_test_exists_#{Process.pid}"

      begin
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_new)}")

        manifest = {
          '2.4.0' => {
            'migration_floor' => '20260530010000',
            'infrastructure' => [
              { 'type' => 'db_rename', 'from' => 'nonexistent_db_xxx', 'to' => test_new }
            ]
          }
        }

        report = described_class.call(manifest_override: manifest)
        rename_actions = report.actions.select { |a| a[:type] == :db_rename }
        expect(rename_actions).to be_empty
      ensure
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_new)}")
        conn.close
      end
    end

    it 'warns when both old and new database names exist' do
      conn = pg_conn
      test_old = "vulcan_upgrade_both_old_#{Process.pid}"
      test_new = "vulcan_upgrade_both_new_#{Process.pid}"

      begin
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_old)}")
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_new)}")

        manifest = {
          '2.4.0' => {
            'migration_floor' => '20260530010000',
            'infrastructure' => [
              { 'type' => 'db_rename', 'from' => test_old, 'to' => test_new }
            ]
          }
        }

        report = described_class.call(manifest_override: manifest)
        expect(report.warnings).to include(a_string_matching(/both.*exist/i))
      ensure
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_old)}")
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_new)}")
        conn.close
      end
    end

    it 'detects current version from schema_migrations via migration_floor' do
      report = described_class.call
      expect(report.current_version).to be_a(String)
      expect(report.current_version).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it 'identifies required stops for multi-version jump' do
      manifest = {
        '2.3.0' => { 'migration_floor' => '20200511155346' },
        '2.4.0' => {
          'migration_floor' => '20990101000000', 'required_stop' => true, 'infrastructure' => []
        },
        '2.5.0' => { 'migration_floor' => '20990201000000' }
      }

      report = described_class.call(manifest_override: manifest)
      expect(report.pending_versions).to include('2.4.0')
    end
  end

  describe '.load_manifest' do
    it 'loads config/upgrade_path.yml' do
      manifest = described_class.load_manifest
      expect(manifest).to be_a(Hash)
      expect(manifest.keys).to all(match(/\A\d+\.\d+\.\d+\z/))
    end

    it 'versions are parseable by Gem::Version' do
      manifest = described_class.load_manifest
      expect { manifest.keys.map { |v| Gem::Version.new(v) } }.not_to raise_error
    end
  end
end
