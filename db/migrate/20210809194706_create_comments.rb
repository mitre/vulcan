# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[6.1]
  def change
    create_table :comments do |t|
      t.references :user, index: true
      t.references :rule, index: true
      t.text :body
      t.timestamps
    end
  end
end
