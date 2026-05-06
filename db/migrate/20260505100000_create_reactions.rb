# frozen_string_literal: true

class CreateReactions < ActiveRecord::Migration[8.0]
  def change
    create_table :reactions do |t|
      t.references :review, null: false, foreign_key: { on_delete: :cascade }
      t.references :user,   null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.timestamps
    end
    add_index :reactions, %i[review_id user_id], unique: true
    add_index :reactions, %i[review_id kind]
  end
end
