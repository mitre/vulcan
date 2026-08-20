# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  # #largest_rule_id built its TO_NUMBER query via
  # string interpolation of the component id. Brakeman-flagged SQL injection
  # (false positive in practice — id is an AR PK — but a real bug class).
  # The fix routes component_id through bound params; only the trusted
  # TO_NUMBER literal remains in the SQL text.
  describe '#largest_rule_id SQL parameterization' do
    it 'filters by component through an Active Record predicate, not interpolated SQL' do
      component = components_component
      sql_events = []
      callback = ->(_, _, _, _, payload) { sql_events << payload }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        component.send(:largest_rule_id)
      end

      to_number_query = sql_events.find { |e| e[:sql].to_s.include?('TO_NUMBER') }
      expect(to_number_query).to be_present,
                                 "Expected a SQL query containing TO_NUMBER; saw #{sql_events.pluck(:sql)}"

      # Active Record renders the component filter as a quoted table.column
      # predicate (`"base_rules"."component_id" = ...`). Raw string interpolation
      # of the id — the Brakeman-flagged regression — would not produce this
      # quoted AR form. This proof is stable across prepared_statements settings
      # and never false-positives on the id's digits coinciding with the trusted
      # TO_NUMBER(rule_id, '999999') literal (the earlier `not_to include(id)`
      # assertion did).
      expect(to_number_query[:sql]).to match(/"base_rules"\."component_id"\s*=/)
    end
  end
end
