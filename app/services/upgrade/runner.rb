# frozen_string_literal: true

module Upgrade
  class BlockedError < StandardError; end

  # Executes upgrade actions produced by Upgrade::Preflight.
  # Handles DB renames (instant ALTER DATABASE RENAME) and env var advisories.
  # Idempotent: skips already-completed actions. Halts on blockers.
  class Runner
    include DatabaseHelper

    Result = Struct.new(:applied, :skipped, :errors, keyword_init: true)

    def self.call(report)
      new(report).call
    end

    def initialize(report)
      @report = report
      @applied = []
      @skipped = []
      @errors = []
    end

    def call
      check_blockers!
      execute_actions
      Result.new(applied: @applied, skipped: @skipped, errors: @errors)
    end

    private

    def check_blockers!
      return if @report.blockers.empty?

      raise BlockedError, @report.blockers.join('; ')
    end

    def execute_actions
      @report.actions.each do |action|
        case action[:type]
        when :db_rename
          execute_db_rename(action)
        when :env_migration
          record_env_migration(action)
        else
          @skipped << action.merge(reason: "unknown action type: #{action[:type]}")
        end
      end
    end

    def execute_db_rename(action)
      old_exists = db_exists?(action[:from])
      new_exists = db_exists?(action[:to])

      if old_exists && !new_exists
        pg_admin_connection do |conn|
          conn.exec("ALTER DATABASE #{conn.escape_identifier(action[:from])} " \
                    "RENAME TO #{conn.escape_identifier(action[:to])}")
        end
        @applied << action
      elsif !old_exists && new_exists
        @skipped << action.merge(reason: 'already renamed')
      elsif old_exists && new_exists
        @skipped << action.merge(reason: 'both exist — resolve manually')
      else
        @skipped << action.merge(reason: 'neither database exists')
      end
    rescue PG::Error => e
      @errors << action.merge(error: e.message)
    end

    def record_env_migration(action)
      @skipped << action.merge(reason: 'env var removal is informational — update .env manually')
    end
  end
end
