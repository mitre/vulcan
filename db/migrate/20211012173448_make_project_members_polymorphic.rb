class MakeProjectMembersPolymorphic < ActiveRecord::Migration[6.1]
  def change
    # Remove this uniqueness index because it needs to be replaced later in the migration 
    remove_index :project_members, column: %i[user_id project_id]

    # Memberships are becoming polymorphic, and can now be related to either
    # a project or component.
    rename_table :project_members, :memberships
    rename_column :memberships, :project_id, :membership_id
    add_column :memberships, :membership_type, :string

    # The `project_members_count` column needs to have a more generic name
    # and also needs to be added to the compoents table as well
    rename_column :projects, :project_members_count, :memberships_count
    add_column :components, :memberships_count, :integer, default: 0

    # Add back a new version of the uniqueness index removed earlier in the migration
    # with one that still accomplishes the goal of "one membership per user for each component/project"
    add_index :memberships, %i[user_id membership_type membership_id], unique: true,  name: 'by_user_and_membership'

    # There is now a new "Least" role available called 'viewer
    change_column_default(
      :memberships,
      :role,
      from: 'author',
      to: 'viewer'
    )
  end
end
