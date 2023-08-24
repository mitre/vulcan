class AddVisibilityToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :visibility, :integer, default: 1
  end
end
