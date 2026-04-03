# frozen_string_literal: true

class AddDescriptionToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :description, :string
  end
end
