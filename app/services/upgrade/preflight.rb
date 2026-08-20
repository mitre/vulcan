# frozen_string_literal: true

module Upgrade
  # Read-only state detection for upgrade path planning.
  # Reads config/upgrade_path.yml (GitLab pattern), checks schema_migrations
  # (Mastodon pattern), and inspects database names to build an action plan.
  class Preflight
    include DatabaseHelper

    Report = Struct.new(:current_version, :pending_versions, :actions, :warnings, :blockers, keyword_init: true)

    MANIFEST_PATH = Rails.root.join('config/upgrade_path.yml').freeze

    def self.call(manifest_override: nil)
      new(manifest_override: manifest_override).call
    end

    def self.load_manifest
      YAML.load_file(MANIFEST_PATH).transform_keys(&:to_s)
    end

    def initialize(manifest_override: nil)
      @manifest = manifest_override || self.class.load_manifest
      @actions = []
      @warnings = []
      @blockers = []
    end

    def call
      detect_current_version
      detect_pending_versions
      detect_infrastructure_actions

      Report.new(
        current_version: @current_version,
        pending_versions: @pending_versions,
        actions: @actions,
        warnings: @warnings,
        blockers: @blockers
      )
    end

    private

    def detect_current_version
      latest_migration = ActiveRecord::Base.connection
                                           .select_value('SELECT MAX(version) FROM schema_migrations')
      @current_version = version_for_migration(latest_migration) || '0.0.0'
    end

    def version_for_migration(migration_ts)
      return nil unless migration_ts

      matched = sorted_versions.select do |_ver, config|
        migration_ts.to_s >= config['migration_floor'].to_s
      end
      matched.last&.first
    end

    def detect_pending_versions
      current = Gem::Version.new(@current_version)
      @pending_versions = sorted_versions
                          .select { |ver, _| Gem::Version.new(ver) > current }
                          .map(&:first)
    end

    def detect_infrastructure_actions
      applied_and_pending_versions.each do |ver, config|
        next unless config['infrastructure']

        config['infrastructure'].each do |step|
          case step['type']
          when 'db_rename'
            check_db_rename(step, ver)
          when 'env_removed'
            check_env_removed(step, ver)
          end
        end
      end
    end

    def check_db_rename(step, version)
      old_exists = db_exists?(step['from'])
      new_exists = db_exists?(step['to'])

      if old_exists && !new_exists
        @actions << { type: :db_rename, from: step['from'], to: step['to'], version: version }
      elsif old_exists && new_exists
        @warnings << "Both #{step['from']} and #{step['to']} exist (v#{version}). Skipping rename — resolve manually."
      end
    end

    def check_env_removed(step, _version)
      return if ENV[step['var']].blank?

      @actions << { type: :env_migration, var: step['var'], replacement: step['replacement'] }
      @warnings << "Environment variable #{step['var']} is set but has been removed. " \
                   "Use #{step['replacement']} instead."
    end

    def sorted_versions
      @sorted_versions ||= @manifest.sort_by { |ver, _| Gem::Version.new(ver) }
    end

    def applied_and_pending_versions
      sorted_versions.to_h
    end
  end
end
