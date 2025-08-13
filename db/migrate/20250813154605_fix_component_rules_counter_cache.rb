# frozen_string_literal: true

class FixComponentRulesCounterCache < ActiveRecord::Migration[7.0]
  def up
    say_with_time 'Fixing component rules_count counter cache' do
      Component.find_each do |component|
        Component.reset_counters(component.id, :rules)
      end
    end
  end

  def down
    # No-op - counter cache will be recalculated as needed
  end
end