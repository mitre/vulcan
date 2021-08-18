class ChangeProjectMemberRoleDefault < ActiveRecord::Migration[6.1]
  def up
    change_column_default :project_members, :role, 'author'
  end

  def down
    change_column_default :project_members, :role, 'editor'
  end
end
