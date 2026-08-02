# frozen_string_literal: true

# Counts the SQL a block issues, so a spec can assert that a serialization path
# fetches its associations up front instead of walking them one row at a time.
#
# An N+1 is invisible to ordinary assertions: the serialized output is identical
# whether the data arrived in one query or four hundred. The query count is the
# only thing that can fail, which makes it the only thing that can guard the
# behavior.
module QueryCountHelpers
  # Schema reflection and transaction bookkeeping are not application queries,
  # and a cache hit costs nothing — none of them should move an assertion.
  IGNORED_NAMES = ['SCHEMA', 'TRANSACTION', 'CACHE', nil].freeze

  # Total plus a per-source breakdown. The breakdown is what makes a failure
  # diagnosable: "412 queries" says something is wrong, "Check Load: 321" says
  # which association is missing from the preload plan.
  QueryReport = Struct.new(:total, :by_name) do
    def to_s
      ["#{total} queries"].concat(
        by_name.sort_by { |_name, count| -count }.map { |name, count| "  #{name}: #{count}" }
      ).join("\n")
    end
  end

  def count_queries
    by_name = Hash.new(0)
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next if IGNORED_NAMES.include?(payload[:name]) || payload[:cached]

      by_name[payload[:name]] += 1
    end

    yield

    QueryReport.new(by_name.values.sum, by_name)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end

RSpec.configure do |config|
  config.include QueryCountHelpers
end
