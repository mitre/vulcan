# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/upgrade/legacy_db_renamer'

RSpec.describe Upgrade::LegacyDbRenamer do
  subject(:renamer) { described_class.new(rename_pairs, **db_config) }

  let(:db_config) do
    {
      host: ENV.fetch('DATABASE_HOST', '127.0.0.1'),
      port: ENV.fetch('DATABASE_PORT', '5432').to_i,
      user: ENV.fetch('POSTGRES_USER', 'postgres'),
      password: ENV.fetch('POSTGRES_PASSWORD', 'postgres')
    }
  end
  let(:rename_pairs) do
    [{ from: 'vulcan_rename_test_old', to: 'vulcan_rename_test_new' }]
  end

  def pg_connect
    PG.connect(host: db_config[:host], port: db_config[:port],
               user: db_config[:user], password: db_config[:password],
               dbname: 'postgres')
  end

  def db_exists?(name)
    conn = pg_connect
    conn.exec_params('SELECT 1 FROM pg_database WHERE datname = $1', [name]).ntuples.positive?
  ensure
    conn&.close
  end

  def create_db(name)
    conn = pg_connect
    conn.exec("CREATE DATABASE #{conn.escape_identifier(name)}")
  ensure
    conn&.close
  end

  def drop_db(name)
    conn = PG.connect(host: ENV.fetch('DATABASE_HOST', '127.0.0.1'),
                      port: ENV.fetch('DATABASE_PORT', '5432').to_i,
                      user: ENV.fetch('POSTGRES_USER', 'postgres'),
                      password: ENV.fetch('POSTGRES_PASSWORD', 'postgres'),
                      dbname: 'postgres')
    conn.exec("DROP DATABASE IF EXISTS #{conn.escape_identifier(name)}")
  ensure
    conn&.close
  end

  after do
    drop_db('vulcan_rename_test_old')
    drop_db('vulcan_rename_test_new')
  end

  describe '#call' do
    context 'when old database exists and new does not' do
      before { create_db('vulcan_rename_test_old') }

      it 'renames old to new' do
        result = renamer.call
        expect(db_exists?('vulcan_rename_test_new')).to be true
        expect(db_exists?('vulcan_rename_test_old')).to be false
        expect(result.applied.size).to eq(1)
        expect(result.applied.first[:from]).to eq('vulcan_rename_test_old')
      end
    end

    context 'when new database already exists' do
      before { create_db('vulcan_rename_test_new') }

      it 'skips with already-renamed reason' do
        result = renamer.call
        expect(result.skipped.size).to eq(1)
        expect(result.skipped.first[:reason]).to eq('already renamed')
      end
    end

    context 'when both databases exist' do
      before do
        create_db('vulcan_rename_test_old')
        create_db('vulcan_rename_test_new')
      end

      it 'skips with manual-resolve warning' do
        result = renamer.call
        expect(result.skipped.size).to eq(1)
        expect(result.skipped.first[:reason]).to match(/both exist/)
      end
    end

    context 'when neither database exists' do
      it 'skips with neither-exists reason' do
        result = renamer.call
        expect(result.skipped.size).to eq(1)
        expect(result.skipped.first[:reason]).to match(/neither/)
      end
    end

    context 'when PostgreSQL is unreachable' do
      let(:db_config) do
        { host: '127.0.0.1', port: 59_999, user: 'nobody', password: 'wrong' }
      end

      # db_exists? returns false on connection failure → "neither exists" → skip
      it 'skips gracefully without raising' do
        result = renamer.call
        expect(result.errors).to be_empty
        expect(result.skipped.size).to eq(1)
        expect(result.skipped.first[:reason]).to match(/neither/)
      end
    end
  end

  describe '.from_env' do
    it 'reads rename pairs from upgrade_path.yml' do
      renamer = described_class.from_env
      expect(renamer).to be_a(described_class)
    end
  end
end
