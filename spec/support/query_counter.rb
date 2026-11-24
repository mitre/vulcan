# frozen_string_literal: true

module QueryCounter
  def count_queries(&)
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next if payload[:name] == 'SCHEMA'
      next if sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
    count
  end

  def assert_query_count_at_most(expected_max, message = nil, &)
    actual = count_queries(&)
    msg = message || "Expected at most #{expected_max} queries, got #{actual}"
    expect(actual).to be <= expected_max, msg
  end
end

RSpec.configure do |config|
  config.include QueryCounter, type: :request
  config.include QueryCounter, type: :model
end
