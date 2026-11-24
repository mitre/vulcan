# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken
namespace :db do
  desc 'Validate data integrity after migration phase'
  task validate: :environment do
    errors = []
    conn = ActiveRecord::Base.connection

    puts '=' * 60
    puts 'DATABASE INTEGRITY VALIDATION'
    puts '=' * 60

    # 1. Row counts
    puts "\n--- Row Counts ---"
    %w[
      users projects components security_requirements_guides stigs
      base_rules reviews reactions rule_satisfactions memberships
      audits additional_questions additional_answers
      project_access_requests
    ].each do |table|
      next unless conn.table_exists?(table)

      count = conn.execute("SELECT COUNT(*) AS c FROM #{conn.quote_table_name(table)}").first['c']
      puts format('  %-40s %8d', table, count)
    end

    # 2. Orphaned FK records
    puts "\n--- Orphaned Record Checks ---"
    orphan_checks = {
      'base_rules → components' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM base_rules r
        LEFT JOIN components c ON r.component_id = c.id
        WHERE c.id IS NULL AND r.type = 'Rule' AND r.deleted_at IS NULL
      SQL
      'base_rules → security_requirements_guides' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM base_rules r
        LEFT JOIN security_requirements_guides s ON r.security_requirements_guide_id = s.id
        WHERE s.id IS NULL AND r.type = 'SrgRule'
      SQL
      'reviews → users' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reviews r
        LEFT JOIN users u ON r.user_id = u.id
        WHERE r.user_id IS NOT NULL AND u.id IS NULL
      SQL
      'reviews → base_rules (rule_id)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reviews r
        LEFT JOIN base_rules br ON r.rule_id = br.id
        WHERE r.rule_id IS NOT NULL AND br.id IS NULL
      SQL
      'reviews → responding_to (self-ref)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reviews r
        LEFT JOIN reviews parent ON r.responding_to_review_id = parent.id
        WHERE r.responding_to_review_id IS NOT NULL AND parent.id IS NULL
      SQL
      'reviews → duplicate_of (self-ref)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reviews r
        LEFT JOIN reviews target ON r.duplicate_of_review_id = target.id
        WHERE r.duplicate_of_review_id IS NOT NULL AND target.id IS NULL
      SQL
      'reactions → reviews' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reactions r
        LEFT JOIN reviews rv ON r.review_id = rv.id
        WHERE rv.id IS NULL
      SQL
      'reactions → users' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM reactions r
        LEFT JOIN users u ON r.user_id = u.id
        WHERE u.id IS NULL
      SQL
      'memberships → users' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM memberships m
        LEFT JOIN users u ON m.user_id = u.id
        WHERE u.id IS NULL
      SQL
      'rule_satisfactions → base_rules (rule_id)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM rule_satisfactions rs
        LEFT JOIN base_rules r ON rs.rule_id = r.id
        WHERE r.id IS NULL
      SQL
      'rule_satisfactions → base_rules (satisfied_by)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM rule_satisfactions rs
        LEFT JOIN base_rules r ON rs.satisfied_by_rule_id = r.id
        WHERE r.id IS NULL
      SQL
      'components → projects' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM components c
        LEFT JOIN projects p ON c.project_id = p.id
        WHERE p.id IS NULL
      SQL
      'components → security_requirements_guides' => <<~SQL.squish
        SELECT COUNT(*) AS c FROM components c
        LEFT JOIN security_requirements_guides s ON c.security_requirements_guide_id = s.id
        WHERE s.id IS NULL
      SQL
    }

    orphan_checks.each do |label, sql|
      count = conn.execute(sql).first['c'].to_i
      status = count.zero? ? '✓' : "✗ #{count} orphaned"
      errors << "Orphaned: #{label} (#{count})" unless count.zero?
      puts format('  %-50s %s', label, status)
    end

    # 3. Unexpected NULLs in required fields
    puts "\n--- NULL Checks (required fields) ---"
    null_checks = {
      'base_rules.type (STI)' =>
        'SELECT COUNT(*) AS c FROM base_rules WHERE type IS NULL',
      'base_rules.component_id (Rules)' =>
        "SELECT COUNT(*) AS c FROM base_rules WHERE type = 'Rule' AND component_id IS NULL AND deleted_at IS NULL",
      'reviews.action' =>
        'SELECT COUNT(*) AS c FROM reviews WHERE action IS NULL',
      'components.project_id' =>
        'SELECT COUNT(*) AS c FROM components WHERE project_id IS NULL',
      'components.prefix' =>
        "SELECT COUNT(*) AS c FROM components WHERE prefix IS NULL OR prefix = ''",
      'memberships.user_id' =>
        'SELECT COUNT(*) AS c FROM memberships WHERE user_id IS NULL',
      'memberships.role' =>
        "SELECT COUNT(*) AS c FROM memberships WHERE role IS NULL OR role = ''"
    }

    null_checks.each do |field, sql|
      count = conn.execute(sql).first['c'].to_i
      status = count.zero? ? '✓' : "✗ #{count} unexpected NULLs"
      errors << "NULLs: #{field} (#{count})" unless count.zero?
      puts format('  %-50s %s', field, status)
    end

    # 4. Duplicate detection
    puts "\n--- Duplicate Checks ---"
    dup_checks = {
      'rule_satisfactions (rule_id, satisfied_by_rule_id)' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM (
          SELECT rule_id, satisfied_by_rule_id
          FROM rule_satisfactions
          GROUP BY rule_id, satisfied_by_rule_id
          HAVING COUNT(*) > 1
        ) dupes
      SQL
      'reactions (review_id, user_id) uniqueness' => <<~SQL.squish,
        SELECT COUNT(*) AS c FROM (
          SELECT review_id, user_id
          FROM reactions
          GROUP BY review_id, user_id
          HAVING COUNT(*) > 1
        ) dupes
      SQL
      'memberships (user_id, membership_type, membership_id)' => <<~SQL.squish
        SELECT COUNT(*) AS c FROM (
          SELECT user_id, membership_type, membership_id
          FROM memberships
          GROUP BY user_id, membership_type, membership_id
          HAVING COUNT(*) > 1
        ) dupes
      SQL
    }

    dup_checks.each do |label, sql|
      count = conn.execute(sql).first['c'].to_i
      status = count.zero? ? '✓' : "✗ #{count} duplicate sets"
      errors << "Duplicates: #{label} (#{count})" unless count.zero?
      puts format('  %-50s %s', label, status)
    end

    # 5. Counter cache consistency
    puts "\n--- Counter Cache Checks ---"
    cache_sql = <<~SQL.squish
      SELECT c.id, c.name, c.rules_count AS cached,
             (SELECT COUNT(*) FROM base_rules r
              WHERE r.component_id = c.id AND r.type = 'Rule'
              AND r.deleted_at IS NULL) AS actual
      FROM components c
      WHERE c.rules_count != (
        SELECT COUNT(*) FROM base_rules r
        WHERE r.component_id = c.id AND r.type = 'Rule'
        AND r.deleted_at IS NULL
      )
    SQL
    mismatches = conn.execute(cache_sql).to_a
    if mismatches.empty?
      puts '  rules_count matches actual                         ✓'
    else
      mismatches.each do |m|
        puts format('  %-50s ✗ cached=%d actual=%d', "Component #{m['id']} (#{m['name']})", m['cached'], m['actual'])
      end
      errors << "Counter cache drift: #{mismatches.size} components"
    end

    # 6. Post-migration override tables (if they exist)
    if conn.table_exists?('rule_check_overrides')
      puts "\n--- Override Table Checks ---"
      override_orphan_sql = <<~SQL.squish
        SELECT COUNT(*) AS c FROM rule_check_overrides rco
        LEFT JOIN base_rules r ON rco.rule_id = r.id
        WHERE r.id IS NULL
      SQL
      count = conn.execute(override_orphan_sql).first['c'].to_i
      status = count.zero? ? '✓' : "✗ #{count} orphaned"
      errors << "Orphaned: rule_check_overrides (#{count})" unless count.zero?
      puts format('  %-50s %s', 'rule_check_overrides → rules', status)
    end

    if conn.table_exists?('rule_description_overrides')
      override_orphan_sql = <<~SQL.squish
        SELECT COUNT(*) AS c FROM rule_description_overrides rdo
        LEFT JOIN base_rules r ON rdo.rule_id = r.id
        WHERE r.id IS NULL
      SQL
      count = conn.execute(override_orphan_sql).first['c'].to_i
      status = count.zero? ? '✓' : "✗ #{count} orphaned"
      errors << "Orphaned: rule_description_overrides (#{count})" unless count.zero?
      puts format('  %-50s %s', 'rule_description_overrides → rules', status)
    end

    # Summary
    puts
    puts '=' * 60
    if errors.empty?
      puts "ALL CHECKS PASSED ✓ (#{orphan_checks.size + null_checks.size + dup_checks.size + 1} checks)"
    else
      puts "#{errors.size} ISSUES FOUND:"
      errors.each { |e| puts "  ✗ #{e}" }
      puts
      puts 'Run db:validate after fixing to re-check.'
      exit 1
    end
    puts '=' * 60
  end
end
# rubocop:enable Style/FormatStringToken
