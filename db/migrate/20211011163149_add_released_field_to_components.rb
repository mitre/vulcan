# frozen_string_literal: true

class AddReleasedFieldToComponents < ActiveRecord::Migration[6.1]
  def change
    add_column :components, :released, :boolean, null: false, default: false
  end
end
