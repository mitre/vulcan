# frozen_string_literal: true

class AddProjectIdFkToRules < ActiveRecord::Migration[6.1]
  def change
    add_reference :rules, :project, foreign_key: true
  end
end
