# frozen_string_literal: true

namespace :upgrade do
  desc 'Pre-upgrade diagnostic — read-only report of what needs to change'
  task preflight: :environment do
    report = Upgrade::Preflight.call

    puts '=' * 60
    puts 'Upgrade preflight report'
    puts '=' * 60
    puts "Current version: #{report.current_version}"
    puts "Pending versions: #{report.pending_versions.any? ? report.pending_versions.join(', ') : 'none (up to date)'}"
    puts

    if report.blockers.any?
      puts "BLOCKERS (#{report.blockers.size}):"
      report.blockers.each { |b| puts "  ✖ #{b}" }
      puts
    end

    if report.actions.any?
      puts "Actions to apply (#{report.actions.size}):"
      report.actions.each do |a|
        case a[:type]
        when :db_rename
          puts "  → Rename database: #{a[:from]} → #{a[:to]} (v#{a[:version]})"
        when :env_migration
          puts "  → Remove env var #{a[:var]}, use #{a[:replacement]} instead"
        else
          puts "  → #{a[:type]}: #{a}"
        end
      end
      puts
    end

    if report.warnings.any?
      puts "Warnings (#{report.warnings.size}):"
      report.warnings.each { |w| puts "  ⚠ #{w}" }
      puts
    end

    puts 'All checks passed — nothing to do.' if report.actions.empty? && report.warnings.empty? && report.blockers.empty?
  end

  desc 'Apply safe auto-fixable upgrade actions (DB renames, backfills)'
  task fix: :environment do
    report = Upgrade::Preflight.call

    if report.actions.empty?
      puts 'Upgrade fix: nothing to do — already up to date.'
      next
    end

    puts "Applying #{report.actions.size} upgrade action(s)..."
    result = Upgrade::Runner.call(report)

    result.applied.each do |a|
      puts "  ✔ Applied: #{a[:type]} #{a[:from]}→#{a[:to] || a[:var]}"
    end

    result.skipped.each do |a|
      puts "  ⏭ Skipped: #{a[:type]} — #{a[:reason]}"
    end

    result.errors.each do |a|
      puts "  ✖ Error: #{a[:type]} — #{a[:error]}"
    end

    puts 'Upgrade fix complete.'
  end

  desc 'Post-upgrade verification — confirm all migrations applied, no legacy state'
  task verify: :environment do
    issues = []

    helper = Object.new.extend(Upgrade::DatabaseHelper)
    %w[vulcan_vue_development vulcan_vue_test vulcan_postgres_production].each do |legacy|
      issues << "Legacy database #{legacy} still exists" if helper.send(:db_exists?, legacy)
    end

    migration_context = ActiveRecord::MigrationContext.new(Rails.root.join('db/migrate'))
    issues << 'Pending migrations exist — run db:migrate' if migration_context.needs_migration?
    issues << 'DB_SUFFIX is set but removed — use DATABASE_NAME instead' if ENV['DB_SUFFIX'].present?

    puts '=' * 60
    puts 'Upgrade verification'
    puts '=' * 60

    if issues.empty?
      puts 'All checks passed.'
    else
      issues.each { |i| puts "  ✖ #{i}" }
      puts
      puts "#{issues.size} issue(s) found. Run `rake upgrade:fix` to resolve."
    end
  end

  desc 'Auto-upgrade: preflight + fix in one shot (for entrypoints)'
  task auto: :environment do
    report = Upgrade::Preflight.call
    next if report.actions.empty? && report.blockers.empty?

    if report.blockers.any?
      warn 'UPGRADE BLOCKED:'
      report.blockers.each { |b| warn "  ✖ #{b}" }
      warn 'Resolve blockers before starting the application.'
      exit 1
    end

    result = Upgrade::Runner.call(report)
    result.applied.each { |a| puts "  Upgraded: #{a[:type]} #{a[:from]}→#{a[:to] || a[:var]}" }
    result.errors.each { |a| warn "  ERROR: #{a[:type]} — #{a[:error]}" }
    exit 1 if result.errors.any?
  end
end
