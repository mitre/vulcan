# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken
namespace :db do
  desc 'Analyze serialization performance and identify bottlenecks'
  task analyze_serialization: :environment do
    require 'benchmark'
    require 'json'

    component = Component.includes(
      rules: %i[reviews disa_rule_descriptions checks references rule_descriptions satisfies satisfied_by]
    ).joins(:rules).where('rules_count > 0').first

    abort 'No component with rules found. Seed the database first.' unless component

    rules = component.rules.to_a
    puts '=' * 70
    puts 'SERIALIZATION PERFORMANCE ANALYSIS'
    puts '=' * 70
    puts "Component: #{component.name} (#{rules.size} rules)"
    puts

    results = { component: component.name, rule_count: rules.size }
    iterations = 5

    # DB fetch time (isolated)
    puts '1. DB fetch (eager load all associations)...'
    fetch_ms = (Benchmark.measure do
      iterations.times do
        Component.includes(
          rules: %i[reviews disa_rule_descriptions checks references]
        ).find(component.id)
      end
    end.real / iterations * 1000).round(1)
    results[:db_fetch_ms] = fetch_ms
    puts "   #{fetch_ms}ms avg"

    # Blueprint views (batch of all rules)
    puts '2. Blueprint serialization (all rules)...'
    %i[navigator viewer editor].each do |view|
      ms = (Benchmark.measure do
        iterations.times { RuleBlueprint.render_as_json(rules, view: view) }
      end.real / iterations * 1000).round(1)
      per_rule = (ms / rules.size).round(3)
      results[:"blueprint_#{view}_ms"] = ms
      results[:"blueprint_#{view}_per_rule_ms"] = per_rule
      puts "   :#{view} — #{ms}ms total, #{per_rule}ms/rule"
    rescue StandardError => e
      puts "   :#{view} — SKIPPED (#{e.message})"
    end

    # JSON.generate overhead
    puts '3. JSON.generate overhead...'
    hash = rules.map { |r| { id: r.id, title: r.title, status: r.status } }
    json_ms = (Benchmark.measure do
      100.times { JSON.generate(hash) }
    end.real / 100 * 1000).round(3)
    results[:json_generate_ms] = json_ms
    puts "   #{json_ms}ms"

    # Full endpoint simulation
    puts '4. Full endpoint simulation (fetch + serialize)...'
    full_ms = (Benchmark.measure do
      iterations.times do
        c = Component.includes(
          rules: %i[reviews disa_rule_descriptions checks]
        ).find(component.id)
        RuleBlueprint.render_as_json(c.rules, view: :viewer)
      end
    end.real / iterations * 1000).round(1)
    results[:full_endpoint_viewer_ms] = full_ms
    puts "   :viewer endpoint: #{full_ms}ms"

    # Query count
    puts '5. Query count...'
    query_count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == 'SCHEMA'
      next if sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      query_count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      c = Component.includes(
        rules: %i[reviews disa_rule_descriptions checks references]
      ).find(component.id)
      c.rules.each do |r|
        r.title
        r.checks.first&.content
        r.disa_rule_descriptions.first&.vuln_discussion
      end
    end
    results[:query_count_eager] = query_count
    puts "   Eager loaded: #{query_count} queries"

    # Summary
    puts
    puts '=' * 70
    puts 'SUMMARY'
    puts '=' * 70
    puts "  #{'DB fetch'.ljust(45)} #{fetch_ms}ms"
    puts "  #{'Blueprint :navigator (all rules)'.ljust(45)} #{results[:blueprint_navigator_ms]}ms"
    puts "  #{'Blueprint :viewer (all rules)'.ljust(45)} #{results[:blueprint_viewer_ms]}ms"
    puts "  #{'Full :viewer endpoint'.ljust(45)} #{full_ms}ms"
    puts "  #{'SQL queries (eager)'.ljust(45)} #{query_count}"
    puts "  #{'JSON overhead'.ljust(45)} #{json_ms}ms"
    puts
    bottleneck = if results[:blueprint_viewer_ms].to_f > fetch_ms * 3
                   'SERIALIZATION (Blueprint > 3x DB fetch)'
                 elsif fetch_ms > 100
                   'DATABASE (fetch > 100ms)'
                 else
                   'Neither dominant (both fast)'
                 end
    puts "Bottleneck: #{bottleneck}"
    puts '=' * 70

    # Save
    output = Rails.root.join('db', 'benchmarks', "db_serialization_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(output, JSON.pretty_generate(
                         captured_at: Time.now.iso8601,
                         phase: ENV.fetch('PHASE', 'unknown'),
                         results: results
                       ))
    puts "\nSaved to #{output}"
  end

  desc 'Analyze content duplication between Rules and SRG templates'
  task analyze_duplication: :environment do
    require 'json'

    conn = ActiveRecord::Base.connection
    puts '=' * 70
    puts 'CONTENT DUPLICATION ANALYSIS'
    puts '=' * 70

    results = {}

    # STI breakdown
    puts "\n--- STI Type Distribution ---"
    conn.execute(
      'SELECT type, COUNT(*) AS cnt FROM base_rules GROUP BY type ORDER BY cnt DESC'
    ).each do |r|
      puts format('  %-20s %6d', r['type'], r['cnt'])
      results[:"sti_#{r['type'].underscore}_count"] = r['cnt'].to_i
    end

    # Check duplication
    puts "\n--- Check Content Duplication ---"
    check_data = conn.execute(<<~SQL.squish).first
      SELECT
        COUNT(*) AS total,
        COUNT(CASE WHEN rc.content = sc.content THEN 1 END) AS identical,
        COUNT(CASE WHEN rc.content != sc.content THEN 1 END) AS different,
        COUNT(CASE WHEN rc.content IS NULL THEN 1 END) AS null_content
      FROM checks rc
      JOIN base_rules r ON rc.base_rule_id = r.id AND r.type = 'Rule'
      JOIN base_rules sr ON r.srg_rule_id = sr.id
      LEFT JOIN checks sc ON sc.base_rule_id = sr.id
    SQL
    total = check_data['total'].to_i
    identical = check_data['identical'].to_i
    different = check_data['different'].to_i
    pct = total.positive? ? (identical.to_f / total * 100).round(1) : 0
    puts "  Total Rule checks:     #{total}"
    puts "  Identical to SRG:      #{identical} (#{pct}%)"
    puts "  Different from SRG:    #{different}"
    results[:check_total] = total
    results[:check_identical] = identical
    results[:check_identical_pct] = pct

    # Description duplication
    puts "\n--- Description Duplication (vuln_discussion) ---"
    desc_data = conn.execute(<<~SQL.squish).first
      SELECT
        COUNT(*) AS total,
        COUNT(CASE WHEN rd.vuln_discussion = sd.vuln_discussion THEN 1 END) AS identical,
        COUNT(CASE WHEN rd.vuln_discussion != sd.vuln_discussion THEN 1 END) AS different
      FROM disa_rule_descriptions rd
      JOIN base_rules r ON rd.base_rule_id = r.id AND r.type = 'Rule'
      JOIN base_rules sr ON r.srg_rule_id = sr.id
      LEFT JOIN disa_rule_descriptions sd ON sd.base_rule_id = sr.id
    SQL
    d_total = desc_data['total'].to_i
    d_identical = desc_data['identical'].to_i
    d_pct = d_total.positive? ? (d_identical.to_f / d_total * 100).round(1) : 0
    puts "  Total:     #{d_total}"
    puts "  Identical: #{d_identical} (#{d_pct}%)"
    puts "  Different: #{desc_data['different']}"
    results[:desc_total] = d_total
    results[:desc_identical] = d_identical
    results[:desc_identical_pct] = d_pct

    # Override analysis
    puts "\n--- Rule Field Override Analysis ---"
    override_data = conn.execute(<<~SQL.squish).first
      SELECT
        COUNT(*) AS total,
        COUNT(CASE WHEN r.title IS NOT NULL AND r.title != sr.title THEN 1 END) AS title_overrides,
        COUNT(CASE WHEN r.fixtext IS NOT NULL AND r.fixtext != sr.fixtext THEN 1 END) AS fixtext_overrides,
        COUNT(CASE WHEN r.vendor_comments IS NOT NULL AND r.vendor_comments != '' THEN 1 END) AS vendor_comments_set,
        COUNT(CASE WHEN r.status IS NOT NULL AND r.status != 'Not Yet Determined' THEN 1 END) AS status_set
      FROM base_rules r
      JOIN base_rules sr ON r.srg_rule_id = sr.id AND sr.type = 'SrgRule'
      WHERE r.type = 'Rule'
    SQL
    o_total = override_data['total'].to_i
    puts "  Total Rules with SRG link: #{o_total}"
    %w[title_overrides fixtext_overrides vendor_comments_set status_set].each do |field|
      val = override_data[field].to_i
      pct_val = o_total.positive? ? (val.to_f / o_total * 100).round(1) : 0
      puts format('  %-30s %6d (%5.1f%%)', field, val, pct_val)
      results[field.to_sym] = val
    end

    # References duplication
    puts "\n--- References by STI Type ---"
    conn.execute(<<~SQL.squish).each do |r|
      SELECT br.type, COUNT(ref.id) AS cnt
      FROM base_rules br
      JOIN "references" ref ON ref.base_rule_id = br.id
      GROUP BY br.type ORDER BY cnt DESC
    SQL
      puts format('  %-20s %6d', r['type'], r['cnt'])
      results[:"refs_#{r['type'].underscore}"] = r['cnt'].to_i
    end

    # Storage
    puts "\n--- Storage Impact ---"
    total_bytes = 0
    %w[base_rules checks disa_rule_descriptions].each do |table|
      size = conn.execute(
        "SELECT pg_total_relation_size('#{table}') AS size"
      ).first['size'].to_i
      total_bytes += size
      mb = (size / 1024.0 / 1024).round(2)
      puts format('  %-30s %8.2f MB', table, mb)
      results[:"storage_#{table}_mb"] = mb
    end
    ref_size = conn.execute(
      "SELECT pg_total_relation_size('\"references\"') AS size"
    ).first['size'].to_i
    total_bytes += ref_size
    puts format('  %-30s %8.2f MB', 'references', (ref_size / 1024.0 / 1024).round(2))
    results[:storage_references_mb] = (ref_size / 1024.0 / 1024).round(2)

    total_mb = (total_bytes / 1024.0 / 1024).round(2)
    est_post = (total_bytes * 0.35 / 1024.0 / 1024).round(2)
    puts "  TOTAL:                         #{total_mb} MB"
    puts "  Estimated post-3NF:            #{est_post} MB (~65% reduction)"
    results[:storage_total_mb] = total_mb
    results[:storage_estimated_post_3nf_mb] = est_post

    # Rules without SRG link
    no_srg = conn.execute(
      "SELECT COUNT(*) AS c FROM base_rules WHERE type = 'Rule' AND srg_rule_id IS NULL"
    ).first['c'].to_i
    puts "\n  Rules with NULL srg_rule_id: #{no_srg}"
    results[:rules_without_srg_link] = no_srg

    puts
    puts '=' * 70

    # Save
    output = Rails.root.join('db', 'benchmarks', "db_duplication_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(output, JSON.pretty_generate(
                         captured_at: Time.now.iso8601,
                         phase: ENV.fetch('PHASE', 'unknown'),
                         results: results
                       ))
    puts "Saved to #{output}"
  end

  desc 'Audit all foreign keys and polymorphic references to base_rules'
  task audit_fks: :environment do
    conn = ActiveRecord::Base.connection
    puts '=' * 70
    puts 'FK & POLYMORPHIC REFERENCE AUDIT'
    puts '=' * 70

    # FK constraints
    puts "\n--- Foreign Keys Referencing base_rules ---"
    fks = conn.execute(<<~SQL.squish)
      SELECT conname, conrelid::regclass AS src_table, confrelid::regclass AS tgt_table,
        pg_get_constraintdef(oid) AS definition
      FROM pg_constraint
      WHERE confrelid = 'base_rules'::regclass
      ORDER BY conrelid::regclass::text
    SQL
    if fks.none?
      puts '  (none — base_rules may have been renamed to rules)'
      # Check rules table instead
      fks = conn.execute(<<~SQL.squish)
        SELECT conname, conrelid::regclass AS src_table, confrelid::regclass AS tgt_table,
          pg_get_constraintdef(oid) AS definition
        FROM pg_constraint
        WHERE confrelid = 'rules'::regclass
        ORDER BY conrelid::regclass::text
      SQL
      puts '  Checking rules table instead...' if fks.any?
    end
    fks.each do |r|
      puts format('  %-25s %-40s %s', r['src_table'], r['conname'], r['definition'])
    end
    puts "  Total: #{fks.count} FKs"

    # Columns named base_rule_id (no FK constraint)
    puts "\n--- Columns Named base_rule_id (Rails-level belongs_to) ---"
    conn.tables.sort.each do |table|
      cols = conn.columns(table).map(&:name)
      next unless cols.include?('base_rule_id')

      count = conn.execute(
        "SELECT COUNT(*) AS c FROM #{conn.quote_table_name(table)}"
      ).first['c']
      puts format('  %-30s base_rule_id  (%d rows)', table, count)
    end

    # Polymorphic BaseRule strings
    puts "\n--- Polymorphic 'BaseRule' Strings in Database ---"
    [
      %w[audits auditable_type],
      %w[audits associated_type],
      %w[reviews commentable_type]
    ].each do |table, col|
      next unless conn.table_exists?(table) && conn.columns(table).map(&:name).include?(col)

      result = conn.execute(
        "SELECT #{conn.quote_column_name(col)}, COUNT(*) AS c " \
        "FROM #{conn.quote_table_name(table)} " \
        "WHERE #{conn.quote_column_name(col)} LIKE '%Rule%' OR #{conn.quote_column_name(col)} LIKE '%Base%' " \
        "GROUP BY #{conn.quote_column_name(col)} ORDER BY c DESC"
      )
      result.each do |r|
        puts format('  %-20s %-25s %-20s %6d rows', table, col, r[col], r['c'])
      end
    end

    # Ruby code references (informational)
    puts "\n--- Hardcoded 'BaseRule' in Ruby Code ---"
    puts '  Run: grep -rn "BaseRule" app/models/ app/controllers/ app/blueprints/'
    puts '  (Cannot execute from rake — run manually or in CI)'

    puts
    puts '=' * 70
  end
end
# rubocop:enable Style/FormatStringToken, Metrics/BlockLength
