# frozen_string_literal: true

# The GIN index that serves search_content and search_phrase. Built
# concurrently so production writes are never blocked.
class IndexBaseRulesSearchable < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :base_rules, :searchable, using: :gin, algorithm: :concurrently
  end
end
