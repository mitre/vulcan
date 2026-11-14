# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken
namespace :db do
  desc 'Capture performance baseline for key database operations'
  task benchmark: :environment do
    require 'benchmark'
    require 'json'

    results = {}
    component = Component.joins(:rules).where('rules_count > 0').first
    project = Project.joins(:components).first

    abort 'No component with rules found. Seed the database first.' unless component
    abort 'No project with components found. Seed the database first.' unless project

    puts 'Benchmarking against:'
    puts "  Component: #{component.name} (#{component.rules_count} rules)"
    puts "  Project:   #{project.name} (#{project.components.count} components)"
    puts

    iterations = 10

    # 1. Component show (full rule load with associations)
    puts '1. Component show (full rule load)...'
    results['component_show_ms'] = (Benchmark.measure do
      iterations.times do
        component.reload
        component.rules.includes(
          :reviews, :disa_rule_descriptions, :checks,
          :satisfies, :satisfied_by,
          srg_rule: %i[disa_rule_descriptions checks]
        ).to_a
      end
    end.real / iterations * 1000).round(1)

    # 2. Paginated comments (triage table)
    puts '2. Paginated comments...'
    results['paginated_comments_ms'] = (Benchmark.measure do
      iterations.times do
        component.paginated_comments(triage_status: 'all', per_page: 25)
      end
    end.real / iterations * 1000).round(1)

    # 3. Pending comment counts (project index)
    puts '3. Pending comment counts...'
    component_ids = project.component_ids
    results['pending_counts_ms'] = (Benchmark.measure do
      iterations.times { Component.pending_comment_counts(component_ids) }
    end.real / iterations * 1000).round(1)

    # 4. SQL query count for component show
    puts '4. Counting queries for component show...'
    query_count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == 'SCHEMA'
      next if sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      query_count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      component.reload
      component.rules.includes(
        :reviews, :disa_rule_descriptions, :checks
      ).to_a
    end
    results['component_show_queries'] = query_count

    # 5. SQL query count for paginated_comments
    puts '5. Counting queries for paginated_comments...'
    query_count = 0
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      component.paginated_comments(triage_status: 'all', per_page: 25)
    end
    results['paginated_comments_queries'] = query_count

    # 6. Component duplicate (write performance)
    puts '6. Component duplicate...'
    if component.rules.exists?(locked: false)
      component.rules.update_all(locked: true) # rubocop:disable Rails/SkipsModelValidations
      component.update_column(:released, true) # rubocop:disable Rails/SkipsModelValidations
    end
    results['component_duplicate_ms'] = (Benchmark.measure do
      dup = component.duplicate(
        new_name: 'Benchmark Dup', new_version: 99,
        new_release: 99, new_title: 'Benchmark', new_description: 'perf test'
      )
      dup&.destroy
    end.real * 1000).round(1)

    # Print results
    puts
    puts '=' * 60
    puts 'PERFORMANCE BASELINE'
    puts '=' * 60
    results.each do |key, value|
      unit = key.end_with?('_queries') ? 'queries' : 'ms'
      puts format('  %-35s %8s %s', key, value, unit)
    end
    puts '=' * 60

    # Save to file
    output_dir = Rails.root.join('tmp')
    FileUtils.mkdir_p(output_dir)
    output_path = output_dir.join("db_benchmark_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(output_path, JSON.pretty_generate(
                              captured_at: Time.now.iso8601,
                              component: { id: component.id, name: component.name, rules_count: component.rules_count },
                              project: { id: project.id, name: project.name },
                              iterations: iterations,
                              results: results
                            ))
    puts "\nSaved to #{output_path}"

    # Compare with previous baseline if exists
    previous = Dir.glob(output_dir.join('db_benchmark_*.json')).reverse[1]
    if previous
      prev_data = JSON.parse(File.read(previous))
      puts "\nComparison with #{File.basename(previous)}:"
      prev_data['results'].each do |key, prev_val|
        next unless results[key]

        curr = results[key].to_f
        prev = prev_val.to_f
        next if prev.zero?

        pct = ((curr - prev) / prev * 100).round(1)
        indicator = if pct > 10
                      "⚠️  +#{pct}% REGRESSION"
                    elsif pct < -10
                      "✅ #{pct}% improvement"
                    else
                      "→ #{pct}% (within threshold)"
                    end
        puts format('  %-35s %s', key, indicator)
      end
    end
  end
end
# rubocop:enable Style/FormatStringToken
