# frozen_string_literal: true

# Backfill the searchable vector for existing rows. Writing searchable = NULL
# is the recompute signal: the BEFORE UPDATE trigger replaces it with the
# real vector in the same statement, keeping the compute logic in its one
# home (base_rule_searchable_vector). Batched so no long transaction holds
# row locks across the whole table.
class BackfillBaseRulesSearchable < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Migration-local model — decoupled from app models and their callbacks.
  class MigrationBaseRule < ActiveRecord::Base
    self.table_name = 'base_rules'
    self.inheritance_column = nil
  end

  def up
    MigrationBaseRule.unscoped.in_batches(of: 1000) do |batch|
      batch.update_all(searchable: nil)
    end
  end

  def down
    # The column is dropped by reverting the add-column migration; the
    # backfilled values need no separate teardown.
  end
end
