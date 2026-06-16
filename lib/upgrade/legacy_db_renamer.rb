# frozen_string_literal: true

require 'bundler/setup'
require 'pg'
require 'yaml'

module Upgrade
  # Renames legacy Vulcan databases to standardized names.
  #
  # Standalone: requires only the pg gem (no Rails, no ActiveRecord).
  # Called by bin/db-rename-legacy BEFORE Rails boots to solve the
  # chicken-and-egg: database.yml expects the new name but the DB
  # may still have the old name.
  class LegacyDbRenamer
    Result = Struct.new(:applied, :skipped, :errors, keyword_init: true)

    UPGRADE_PATH = File.expand_path('../../config/upgrade_path.yml', __dir__)

    def self.from_env(manifest_path: UPGRADE_PATH)
      pairs = extract_rename_pairs(manifest_path)
      new(
        pairs,
        host: ENV.fetch('DATABASE_HOST', '127.0.0.1'),
        port: ENV.fetch('DATABASE_PORT', '5432').to_i,
        user: ENV.fetch('POSTGRES_USER', 'postgres'),
        password: ENV.fetch('POSTGRES_PASSWORD', 'postgres')
      )
    end

    def self.extract_rename_pairs(manifest_path)
      manifest = YAML.load_file(manifest_path)
      pairs = []
      manifest.each_value do |config|
        next unless config.is_a?(Hash) && config['infrastructure']

        config['infrastructure'].each do |step|
          next unless step['type'] == 'db_rename'

          pairs << { from: step['from'], to: step['to'] }
        end
      end
      pairs
    end

    def initialize(rename_pairs, host:, port:, user:, password:)
      @rename_pairs = rename_pairs
      @host = host
      @port = port
      @user = user
      @password = password
      @applied = []
      @skipped = []
      @errors = []
    end

    def call
      @rename_pairs.each { |pair| process_rename(pair) }
      Result.new(applied: @applied, skipped: @skipped, errors: @errors)
    end

    private

    def process_rename(pair)
      old_name = pair[:from]
      new_name = pair[:to]

      old_exists = db_exists?(old_name)
      new_exists = db_exists?(new_name)

      if old_exists && !new_exists
        execute_rename(old_name, new_name)
        @applied << pair
      elsif !old_exists && new_exists
        @skipped << pair.merge(reason: 'already renamed')
      elsif old_exists && new_exists
        @skipped << pair.merge(reason: 'both exist — resolve manually')
      else
        @skipped << pair.merge(reason: 'neither database exists')
      end
    rescue PG::Error => e
      @errors << pair.merge(error: e.message)
    end

    def execute_rename(old_name, new_name)
      with_connection do |conn|
        conn.exec("ALTER DATABASE #{conn.escape_identifier(old_name)} " \
                  "RENAME TO #{conn.escape_identifier(new_name)}")
      end
    end

    def db_exists?(name)
      with_connection do |conn|
        conn.exec_params('SELECT 1 FROM pg_database WHERE datname = $1', [name]).ntuples.positive?
      end
    rescue PG::Error
      false
    end

    def with_connection
      conn = PG.connect(host: @host, port: @port, user: @user,
                        password: @password, dbname: 'postgres')
      yield conn
    ensure
      conn&.close
    end
  end
end
