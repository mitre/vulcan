class ComponentsBasedOnSrgInsteadOfProjects < ActiveRecord::Migration[6.1]
  def change
    # Since components now have rules instead of projects,
    # then components need to be based on an SRG instead of
    # projects being based on an SRG
    remove_column :projects, :prefix, :string
    remove_column :projects, :security_requirements_guide_id, :bigint

    add_column :components, :prefix, :string
    add_column :components, :security_requirements_guide_id, :bigint
  end
end
