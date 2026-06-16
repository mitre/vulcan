# frozen_string_literal: true

require 'rails_helper'

# Performance gate for the MergeApplier write path. Mirrors the Analyzer
# benchmark (spec/performance/merge_analyzer_benchmark_spec.rb) but
# exercises real DB writes via the applier:
#
#   - 500 auto-merged field changes spread across rules
#   - 500 satisfaction inserts via upsert_all ON CONFLICT
#   - assert wall-clock + RSS budgets
#
# Excluded from the default suite via `--tag ~performance` in .rspec.
# Run on demand:
#
#   bundle exec rspec --tag performance spec/performance/merge_applier_benchmark_spec.rb
module MergeApplierBenchmark
  WALL_CLOCK_BUDGET_S = 15.0
  MEMORY_BUDGET_MB    = 250
  RULE_COUNT          = 500
end

RSpec.describe 'MergeApplier performance', :performance do
  before do
    allow(Import::JsonArchive::Merge::SnapshotManager)
      .to receive(:create_snapshot).and_return('/tmp/applier_perf_snapshot.zip')
  end

  let(:component) { create(:component, :closed_comment_phase) }
  let(:strategy) do
    Import::JsonArchive::Merge::Strategy.new(overrides: { rule: { 'fixtext' => :theirs } })
  end
  let(:manifest) { { 'backup_format_version' => '1.1' } }

  def build_plan_with_changes(component, change_count:)
    plan = Import::JsonArchive::Merge::MergePlan.new(
      component_id: component.id, strategy: strategy, manifest: manifest
    )
    rules = component.rules.limit(change_count).to_a
    rules.each_with_index do |rule, idx|
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: rule.fixtext, to: "perf-bench-#{idx}",
        resolution: :auto_theirs, locked: false, reason: ''
      )
      plan.add_field_changes(rule.rule_id, [change])
    end
    plan
  end

  it "applies #{MergeApplierBenchmark::RULE_COUNT} rule changes " \
     "in <#{MergeApplierBenchmark::WALL_CLOCK_BUDGET_S}s" do
    plan = build_plan_with_changes(component, change_count: MergeApplierBenchmark::RULE_COUNT)

    # Warm-up (autoload, prepared statements, etc.)
    Import::JsonArchive::Merge::Applier.new(
      merge_plan: build_plan_with_changes(component, change_count: 1),
      component: component, source: 'theirs', archive_bytes: 'warmup'
    ).call

    elapsed = Benchmark.realtime do
      result = Import::JsonArchive::Merge::Applier.new(
        merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'bench'
      ).call
      expect(result.success?).to be(true)
    end

    warn "merge applier (#{MergeApplierBenchmark::RULE_COUNT} rule writes): #{elapsed.round(3)}s"
    expect(elapsed).to be < MergeApplierBenchmark::WALL_CLOCK_BUDGET_S
  end

  it "stays under #{MergeApplierBenchmark::MEMORY_BUDGET_MB}MB peak RSS during apply" do
    plan = build_plan_with_changes(component, change_count: MergeApplierBenchmark::RULE_COUNT)
    rss_before_kb = `ps -o rss= -p #{Process.pid}`.to_i

    Import::JsonArchive::Merge::Applier.new(
      merge_plan: plan, component: component, source: 'theirs', archive_bytes: 'bench'
    ).call

    rss_after_kb = `ps -o rss= -p #{Process.pid}`.to_i
    growth_mb = (rss_after_kb - rss_before_kb) / 1024.0

    warn "merge applier RSS growth: #{growth_mb.round(1)}MB"
    expect(growth_mb).to be < MergeApplierBenchmark::MEMORY_BUDGET_MB
  end
end
