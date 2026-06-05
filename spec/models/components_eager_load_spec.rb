# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  # status_counts / releasable / reviews each ran fresh SQL
  # despite set_component preloading rules. Use in-memory rules when
  # association_cached?(:rules); fall back to SQL when not preloaded.
  describe 'eager-load-aware methods' do
    def capture_base_rules_sql(&)
      sql = []
      cb = ->(_, _, _, _, p) { sql << p[:sql] if p[:sql].to_s.match?(/FROM\s+["']?base_rules/i) }
      ActiveSupport::Notifications.subscribed(cb, 'sql.active_record', &)
      sql
    end

    describe '#status_counts' do
      it 'uses in-memory rules when preloaded' do
        preloaded = Component.includes(:rules).find(shared_component.id)
        sql = capture_base_rules_sql { preloaded.status_counts }
        expect(sql).to be_empty,
                       "expected no SQL on base_rules when rules are preloaded; got:\n#{sql.join("\n")}"
      end

      it 'falls back to SQL when rules are NOT preloaded' do
        fresh = Component.find(shared_component.id)
        sql = capture_base_rules_sql { fresh.status_counts }
        expect(sql).not_to be_empty, 'expected a base_rules SQL when rules not preloaded'
      end

      it 'returns the same hash shape regardless of preload state' do
        preloaded = Component.includes(:rules).find(shared_component.id)
        fresh = Component.find(shared_component.id)
        expect(preloaded.status_counts).to eq(fresh.status_counts)
      end
    end

    describe '#releasable' do
      it 'uses in-memory rules when preloaded' do
        preloaded = Component.includes(:rules).find(shared_component.id)
        sql = capture_base_rules_sql { preloaded.releasable }
        expect(sql).to be_empty,
                       "expected no SQL on base_rules when rules are preloaded; got:\n#{sql.join("\n")}"
      end

      it 'returns the same result regardless of preload state' do
        preloaded = Component.includes(:rules).find(shared_component.id)
        fresh = Component.find(shared_component.id)
        expect(preloaded.releasable).to eq(fresh.releasable)
      end
    end

    describe '#reviews' do
      it 'uses in-memory rules + reviews when both preloaded' do
        preloaded = Component.includes(rules: :reviews).find(shared_component.id)
        sql = []
        cb = lambda do |_, _, _, _, p|
          s = p[:sql].to_s
          sql << s if s.match?(/FROM\s+["']?(base_rules|reviews)["']?/i)
        end
        ActiveSupport::Notifications.subscribed(cb, 'sql.active_record') do
          preloaded.reviews
        end
        expect(sql).to be_empty,
                       "expected no SQL on base_rules or reviews when both preloaded; got:\n#{sql.join("\n")}"
      end

      it 'returns the same payload shape regardless of preload state' do
        preloaded = Component.includes(rules: :reviews).find(shared_component.id)
        fresh = Component.find(shared_component.id)
        # Same key set, same review ids in the same order.
        expect(preloaded.reviews.pluck('id')).to eq(fresh.reviews.pluck('id'))
      end
    end
  end

  # (§18.4): #largest_rule_id built its TO_NUMBER query via
  # string interpolation of the component id. Brakeman-flagged SQL injection
  # (false positive in practice — id is an AR PK — but a real bug class).
  # The fix routes component_id through bound params; only the trusted
  # TO_NUMBER literal remains in the SQL text.
  describe '#largest_rule_id SQL parameterization' do
    it 'parameterizes component ID in max rule_id SQL query' do
      component = shared_component
      sql_events = []
      callback = ->(_, _, _, _, payload) { sql_events << payload }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        component.send(:largest_rule_id)
      end

      to_number_query = sql_events.find { |e| e[:sql].to_s.include?('TO_NUMBER') }
      expect(to_number_query).to be_present,
                                 "Expected a SQL query containing TO_NUMBER; saw #{sql_events.pluck(:sql)}"

      # Parameterization: the component id should NOT be inlined as a literal.
      expect(to_number_query[:sql]).not_to include(component.id.to_s),
                                           "Expected component_id to be bound, not interpolated: #{to_number_query[:sql]}"

      # And it SHOULD show up in the bind values.
      bind_values = (to_number_query[:binds] || []).map { |b| b.respond_to?(:value) ? b.value : b }
      expect(bind_values).to include(component.id),
                             "Expected component_id #{component.id} in binds; got #{bind_values}"
    end
  end
end
