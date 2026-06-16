# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Upgrade::Runner do
  let(:pg_config) do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    { host: config[:host], port: config[:port], user: config[:username], password: config[:password] }
  end

  def pg_conn
    PG.connect(host: pg_config[:host], port: pg_config[:port],
               user: pg_config[:user], password: pg_config[:password], dbname: 'postgres')
  end

  def db_exists?(name)
    conn = pg_conn
    conn.exec_params('SELECT 1 FROM pg_database WHERE datname = $1', [name]).ntuples.positive?
  ensure
    conn&.close
  end

  describe '.call' do
    it 'executes db_rename actions' do
      conn = pg_conn
      test_old = "vulcan_runner_old_#{Process.pid}"
      test_new = "vulcan_runner_new_#{Process.pid}"

      begin
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_old)}")

        report = Upgrade::Preflight::Report.new(
          current_version: '2.3.7',
          pending_versions: ['2.4.0'],
          actions: [{ type: :db_rename, from: test_old, to: test_new, version: '2.4.0' }],
          warnings: [],
          blockers: []
        )

        result = described_class.call(report)

        expect(db_exists?(test_new)).to be true
        expect(db_exists?(test_old)).to be false
        expect(result.applied).to include(a_hash_including(type: :db_rename, from: test_old))
        expect(result.skipped).to be_empty
        expect(result.errors).to be_empty
      ensure
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_old)}")
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_new)}")
        conn.close
      end
    end

    it 'is idempotent — second run skips completed actions' do
      conn = pg_conn
      test_old = "vulcan_runner_idem_old_#{Process.pid}"
      test_new = "vulcan_runner_idem_new_#{Process.pid}"

      begin
        conn.exec("CREATE DATABASE #{conn.escape_identifier(test_old)}")

        report = Upgrade::Preflight::Report.new(
          current_version: '2.3.7',
          pending_versions: ['2.4.0'],
          actions: [{ type: :db_rename, from: test_old, to: test_new, version: '2.4.0' }],
          warnings: [],
          blockers: []
        )

        described_class.call(report)

        # Run again with same actions — old no longer exists, new does
        result2 = described_class.call(report)
        expect(result2.applied).to be_empty
        expect(result2.skipped).to include(a_hash_including(type: :db_rename))
        expect(result2.errors).to be_empty
      ensure
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_old)}")
        conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(test_new)}")
        conn.close
      end
    end

    it 'halts on blockers without applying any actions' do
      report = Upgrade::Preflight::Report.new(
        current_version: '2.2.0',
        pending_versions: ['2.3.0', '2.4.0'],
        actions: [{ type: :db_rename, from: 'fake_old', to: 'fake_new', version: '2.4.0' }],
        warnings: [],
        blockers: ['Must upgrade to v2.3.0 before proceeding']
      )

      expect { described_class.call(report) }.to raise_error(Upgrade::BlockedError, /v2\.3\.0/)
    end

    it 'returns result with applied, skipped, errors arrays' do
      report = Upgrade::Preflight::Report.new(
        current_version: '2.4.0',
        pending_versions: [],
        actions: [],
        warnings: [],
        blockers: []
      )

      result = described_class.call(report)
      expect(result.applied).to eq([])
      expect(result.skipped).to eq([])
      expect(result.errors).to eq([])
    end
  end
end
