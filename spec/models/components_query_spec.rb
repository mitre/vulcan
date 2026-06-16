# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  # (§18.4): #largest_rule_id built its TO_NUMBER query via
  # string interpolation of the component id. Brakeman-flagged SQL injection
  # (false positive in practice — id is an AR PK — but a real bug class).
  # The fix routes component_id through bound params; only the trusted
  # TO_NUMBER literal remains in the SQL text.
  describe '#largest_rule_id SQL parameterization' do
    it 'parameterizes component ID in max rule_id SQL query' do
      component = components_component
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
