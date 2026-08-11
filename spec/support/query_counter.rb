# frozen_string_literal: true

# Helper for asserting a bounded number of SQL queries inside a block.
# Used by performance specs to guard against N+1 regressions introduced
# during the DB 3NF redesign (see docs/plans/DATABASE-COMPLETE-REDESIGN-v2.md).
#
# Usage:
#   include QueryCounter
#   assert_query_count(8) { get "/components/#{component.id}.json" }
#
# Or capture the count for a custom expectation:
#   count = count_queries { component.rules.with_display_fallbacks.to_a }
#   expect(count).to be <= 3
module QueryCounter
  IGNORED_QUERY = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i

  # Counts real data queries fired inside the block. Schema introspection
  # and transaction-control statements are excluded so the count reflects
  # application query patterns, not adapter bookkeeping.
  def count_queries
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == 'SCHEMA'
      next if payload[:cached]
      next if payload[:sql].to_s.match?(IGNORED_QUERY)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { yield }
    count
  end

  def assert_query_count(expected_max, message = nil)
    count = count_queries { yield }
    expect(count).to(
      be <= expected_max,
      message || "Expected at most #{expected_max} queries, got #{count}"
    )
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
