# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding demo comments for public-comment-review workflow...'

require_relative '../../../lib/seed_context'

ctx = SeedContext.new

ctx.project('Container Platform')
container_component = ctx.component('Container Platform')

if container_component.nil?
  puts '  No Container Platform component — skipping comment seeds'
  return
end

rules = ctx.rules_for(container_component)
if rules.size < 4
  puts "  Not enough rules on Container Platform (#{rules.size}) — skipping"
  return
end

# ── Cleanup orphaned reviews from deleted components ──
orphaned = SeedHelpers.cleanup_orphaned_reviews!
puts "  Cleaned up #{orphaned} orphaned review(s)" if orphaned.positive?

# ── Load thread definitions from YAML data file ──
threads = SeedHelpers.load_threads
users_hash = SeedContext::SYMBOL_TO_EMAIL.transform_values { |email| ctx.user(email) }

# ── Seed all rule-scoped threads ──
threads['rule_threads'].each do |thread|
  SeedHelpers.seed_thread(thread, rules: rules, users: users_hash, component: container_component)
end

# ── Seed component-scoped threads ──
threads['component_threads'].each do |thread|
  thread_with_nil_rule = thread.merge(rule: nil)
  SeedHelpers.seed_thread(thread_with_nil_rule, rules: rules, users: users_hash, component: container_component)
end

# ── Report ──
top_level = Review.where(action: 'comment', responding_to_review_id: nil).count
replies = Review.where(action: 'comment').where.not(responding_to_review_id: nil).count
deep_threads = Review.where(action: 'comment').where.not(responding_to_review_id: nil)
                     .group(:responding_to_review_id).having('count(*) >= 3').count.size
puts "  Container Platform: #{top_level} top-level + #{replies} replies (#{deep_threads} threads with 3+ replies)"
# rubocop:enable Rails/Output
