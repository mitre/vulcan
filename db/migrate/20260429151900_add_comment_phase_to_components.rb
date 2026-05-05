# frozen_string_literal: true

class AddCommentPhaseToComponents < ActiveRecord::Migration[8.0]
  def change
    change_table :components, bulk: true do |t|
      t.string   :comment_phase, default: 'draft', null: false
      # values: draft | open | adjudication | final
      t.datetime :comment_period_starts_at
      t.datetime :comment_period_ends_at

      t.index :comment_phase
      t.index %i[comment_period_starts_at comment_period_ends_at],
              name: 'index_components_on_comment_period_dates'
    end
  end
end
