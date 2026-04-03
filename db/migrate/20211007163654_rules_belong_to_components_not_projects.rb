# frozen_string_literal: true

class RulesBelongToComponentsNotProjects < ActiveRecord::Migration[6.1]
  def change
    # Rules should no longer belong to projects
    remove_reference :rules, :project, foreign_key: true

    # Rules should instead now only belong to components
    add_reference :rules, :component, foreign_key: true
  end
end
