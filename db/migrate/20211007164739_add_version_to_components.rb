# frozen_string_literal: true

class AddVersionToComponents < ActiveRecord::Migration[6.1]
  def change
    add_column :components, :version, :string
  end
end
