# frozen_string_literal: true

require 'rails_helper'

# Performance gate for the MergeAnalyzer pipeline. Builds 500 rules and
# 5000 reviews entirely in-memory (via the SyncRakeRunner virtual adapters
# so no DB IO factors into the timing), runs the full analyzer, and
# asserts both wall-clock and memory ceilings.
#
# Excluded from the default suite via `--tag ~performance` in .rspec.
# Run on demand:
#
#   bundle exec rspec --tag performance spec/performance/merge_analyzer_benchmark_spec.rb
module MergeAnalyzerBenchmark
  WALL_CLOCK_BUDGET_S = 10.0
  MEMORY_BUDGET_MB = 200
  RULE_COUNT = 500
  REVIEWS_PER_RULE = 10 # 500 * 10 = 5000
end

RSpec.describe 'MergeAnalyzer performance', :performance do
  def build_rules(count)
    Array.new(count) do |i|
      {
        'rule_id' => "V-#{format('%05d', i)}",
        'title' => "Rule #{i} title",
        'fixtext' => "Fix #{i}",
        'rule_severity' => %w[low medium high].sample,
        'status' => 'Applicable - Configurable',
        'locked_fields' => []
      }
    end
  end

  def build_reviews(rule_count, per_rule)
    # Use Time.utc so the ISO string format ("Z" suffix) matches what the
    # Analyzer's review_to_hash emits — the matcher keys on string equality.
    base_time = Time.utc(2026, 1, 1)
    counter = 0
    Array.new(rule_count * per_rule) do |i|
      counter += 1
      rule_idx = i / per_rule
      {
        'rule_id' => "V-#{format('%05d', rule_idx)}",
        'comment' => "Review comment #{counter}",
        'created_at' => (base_time + counter.seconds).iso8601(6),
        'external_id' => counter,
        'responding_to_external_id' => nil
      }
    end
  end

  let(:ours_rules)   { build_rules(MergeAnalyzerBenchmark::RULE_COUNT) }
  let(:theirs_rules) do
    # Half the rules diverge on title to force real diff work.
    build_rules(MergeAnalyzerBenchmark::RULE_COUNT).each_with_index do |rule, idx|
      rule['title'] = "DIVERGED #{idx}" if idx.even?
    end
  end

  let(:ours_reviews)   { build_reviews(MergeAnalyzerBenchmark::RULE_COUNT, MergeAnalyzerBenchmark::REVIEWS_PER_RULE) }
  let(:theirs_reviews) do
    # 80% identical, 20% diverged so matcher does meaningful partitioning.
    build_reviews(MergeAnalyzerBenchmark::RULE_COUNT, MergeAnalyzerBenchmark::REVIEWS_PER_RULE).each_with_index do |r, idx|
      r['comment'] = "diff #{idx}" if (idx % 5).zero?
    end
  end

  let(:ours_input) do
    Import::JsonArchive::Merge::MergeInput.from_json_archive({
                                                               'component' => { 'name' => 'PerfTest' },
                                                               'rules' => ours_rules,
                                                               'reviews' => ours_reviews,
                                                               'satisfactions' => []
                                                             })
  end
  let(:theirs_input) do
    Import::JsonArchive::Merge::MergeInput.from_json_archive({
                                                               'component' => { 'name' => 'PerfTest' },
                                                               'rules' => theirs_rules,
                                                               'reviews' => theirs_reviews,
                                                               'satisfactions' => []
                                                             })
  end
  let(:virtual_component) { Import::JsonArchive::Merge::SyncRakeRunner::VirtualComponent.new(ours_input) }

  it "analyzes #{MergeAnalyzerBenchmark::RULE_COUNT} rules / #{MergeAnalyzerBenchmark::RULE_COUNT * MergeAnalyzerBenchmark::REVIEWS_PER_RULE} reviews in <#{MergeAnalyzerBenchmark::WALL_CLOCK_BUDGET_S}s" do
    # Warm any first-call autoloading / monkey-patching.
    Import::JsonArchive::Merge::Analyzer.new(
      merge_input: theirs_input, component: virtual_component,
      strategy: Import::JsonArchive::Merge::Strategy.new, manifest: theirs_input.manifest
    ).call

    elapsed = Benchmark.realtime do
      plan = Import::JsonArchive::Merge::Analyzer.new(
        merge_input: theirs_input, component: virtual_component,
        strategy: Import::JsonArchive::Merge::Strategy.new, manifest: theirs_input.manifest
      ).call
      expect(plan.summary['rules']['matched']).to eq(MergeAnalyzerBenchmark::RULE_COUNT)
      expect(plan.summary['reviews']['matched']).to be > 0
    end

    warn "merge analyzer (#{MergeAnalyzerBenchmark::RULE_COUNT}/#{MergeAnalyzerBenchmark::RULE_COUNT * MergeAnalyzerBenchmark::REVIEWS_PER_RULE}): #{elapsed.round(3)}s"
    expect(elapsed).to be < MergeAnalyzerBenchmark::WALL_CLOCK_BUDGET_S
  end

  it "stays under #{MergeAnalyzerBenchmark::MEMORY_BUDGET_MB}MB peak RSS during analysis" do
    rss_before_kb = `ps -o rss= -p #{Process.pid}`.to_i

    plan = Import::JsonArchive::Merge::Analyzer.new(
      merge_input: theirs_input, component: virtual_component,
      strategy: Import::JsonArchive::Merge::Strategy.new, manifest: theirs_input.manifest
    ).call
    expect(plan).to be_a(Import::JsonArchive::Merge::MergePlan)

    rss_after_kb = `ps -o rss= -p #{Process.pid}`.to_i
    growth_mb = (rss_after_kb - rss_before_kb) / 1024.0

    warn "merge analyzer RSS growth: #{growth_mb.round(1)}MB"
    expect(growth_mb).to be < MergeAnalyzerBenchmark::MEMORY_BUDGET_MB
  end
end
