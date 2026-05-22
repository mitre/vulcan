# frozen_string_literal: true

# Performance baseline harness for the DB 3NF redesign.
# See docs/plans/DATABASE-COMPLETE-REDESIGN-v2.md — "Performance Benchmarks".
#
# Run before Phase 0 and after each phase to track regression. Writes a
# JSON snapshot to tmp/ so successive runs can be diffed.
namespace :db do
  desc 'Capture performance baseline for key endpoints'
  task benchmark: :environment do
    require 'benchmark'

    component = Component.joins(:rules).first
    project = Project.first

    if component.nil? || project.nil?
      warn 'db:benchmark needs at least one project with a component that has rules. ' \
           'Seed data first (rake dev:prime) or run against a production-like dump.'
      next
    end

    results = {}

    # 1. Component show (full rule load)
    results['component_show'] = Benchmark.measure do
      10.times { component.reload.rules.includes(:reviews, :disa_rule_descriptions, :checks).to_a }
    end.real / 10

    # 2. Rules summary (counter cache target — Phase 6)
    if component.respond_to?(:batch_rules_summary)
      results['rules_summary'] = Benchmark.measure do
        10.times { component.batch_rules_summary }
      end.real / 10
    end

    # 3. SQL query count per component show
    counter = QueryCount.new
    ActiveSupport::Notifications.subscribed(counter.to_proc, 'sql.active_record') do
      component.reload.rules.includes(:reviews, :disa_rule_descriptions, :checks).to_a
    end
    results['component_show_queries'] = counter.count

    puts "\n=== Performance Baseline ==="
    results.each { |k, v| puts "  #{k}: #{v.is_a?(Float) ? format('%.4fs', v) : v}" }

    path = Rails.root.join('tmp/db_benchmark_baseline.json')
    File.write(path, JSON.pretty_generate(results))
    puts "\nSaved to #{path}"
  end

  # Small helper so the SQL counter logic stays readable.
  class QueryCount
    IGNORED = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i
    attr_reader :count

    def initialize
      @count = 0
    end

    def to_proc
      lambda do |_name, _start, _finish, _id, payload|
        return if payload[:name] == 'SCHEMA' || payload[:cached]
        return if payload[:sql].to_s.match?(IGNORED)

        @count += 1
      end
    end
  end
end
