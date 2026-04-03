# frozen_string_literal: true

class CreateRules < ActiveRecord::Migration[6.1]
  def change
    create_table :rules do |t|
      t.boolean :locked, default: false
      t.timestamps
    end
  end
end
