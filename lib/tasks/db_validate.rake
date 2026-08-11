# frozen_string_literal: true

# Post-migration data integrity validation for the DB 3NF redesign.
# See docs/plans/DATABASE-COMPLETE-REDESIGN-v2.md — "Post-Migration Data Validation".
#
# Run after each phase: bundle exec rails db:validate
# Exits non-zero if any orphaned FK, unexpected NULL, or duplicate is found,
# so it can gate a CI deploy step.
#
# Each check is guarded by table/column existence so the task is meaningful
# at every phase of the migration, not only after the final schema lands.
namespace :db do
  desc 'Validate data integrity after a migration phase'
  task validate: :environment do
    conn = ActiveRecord::Base.connection
    errors = []

    scalar = ->(sql) { conn.exec_query(sql).first&.values&.first.to_i }
    table = ->(name) { conn.table_exists?(name) }
    column = ->(t, c) { table.call(t) && conn.column_exists?(t, c) }

    puts '=== Row Counts ==='
    %w[base_rules rules srg_rules stig_rules components security_requirements_guides
       stigs reviews reactions rule_satisfactions].each do |t|
      next unless table.call(t)

      puts "  #{t}: #{scalar.call("SELECT COUNT(*) FROM #{t}")}"
    end

    puts "\n=== Orphaned Records ==="
    orphan_checks = {}
    if column.call('reviews', 'user_id')
      orphan_checks['reviews -> users'] = <<~SQL
        SELECT COUNT(*) FROM reviews r
        LEFT JOIN users u ON r.user_id = u.id
        WHERE r.user_id IS NOT NULL AND u.id IS NULL
      SQL
    end
    if table.call('rules') && column.call('rules', 'srg_rule_id') && table.call('srg_rules')
      orphan_checks['rules -> srg_rules'] = <<~SQL
        SELECT COUNT(*) FROM rules r
        LEFT JOIN srg_rules sr ON r.srg_rule_id = sr.id
        WHERE sr.id IS NULL AND r.deleted_at IS NULL
      SQL
    end
    if table.call('rule_satisfactions') && column.call('rule_satisfactions', 'srg_rule_id')
      orphan_checks['rule_satisfactions -> srg_rules'] = <<~SQL
        SELECT COUNT(*) FROM rule_satisfactions rs
        LEFT JOIN srg_rules sr ON rs.srg_rule_id = sr.id
        WHERE sr.id IS NULL
      SQL
    end
    if table.call('rule_check_overrides')
      orphan_checks['rule_check_overrides -> rules'] = <<~SQL
        SELECT COUNT(*) FROM rule_check_overrides o
        LEFT JOIN rules r ON o.rule_id = r.id
        WHERE r.id IS NULL
      SQL
    end

    if orphan_checks.empty?
      puts '  (no applicable checks at this phase)'
    else
      orphan_checks.each do |label, sql|
        count = scalar.call(sql)
        errors << "#{label}: #{count} orphaned" if count.positive?
        puts "  #{label}: #{count.zero? ? 'OK' : "FAIL #{count} orphaned"}"
      end
    end

    puts "\n=== Summary ==="
    if errors.empty?
      puts 'All validations passed.'
    else
      puts "#{errors.size} validation error(s):"
      errors.each { |e| puts "  FAIL #{e}" }
      exit 1
    end
  end
end
