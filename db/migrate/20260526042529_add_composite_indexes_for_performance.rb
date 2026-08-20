# frozen_string_literal: true

class AddCompositeIndexesForPerformance < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # Component#status_counts: rules.where(deleted_at: nil).group(:status).count
    add_index :base_rules, %i[component_id deleted_at status],
              name: 'index_base_rules_on_component_deleted_status',
              algorithm: :concurrently,
              if_not_exists: true

    # Project#details: rules.group(:locked).count and
    # rules.where(locked: false).group(CASE review_requestor_id).count
    add_index :base_rules, %i[component_id locked review_requestor_id],
              name: 'index_base_rules_on_component_locked_requestor',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
