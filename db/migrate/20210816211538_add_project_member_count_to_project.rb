# frozen_string_literal: true

class AddProjectMemberCountToProject < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :project_members_count, :integer, default: 0
  end
end
