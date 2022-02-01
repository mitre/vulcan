class MakeComponentsChildToSingleProject < ActiveRecord::Migration[6.1]
  def change
    remove_index :components, name: :index_components_on_child_project_id
    remove_index :components, name: :components_parent_child_id_index
    remove_column :components, :child_project_id, :bigint

    # Allow a component to reference another component so that it can be overlaid
    add_reference :components, :component, foreign_key: true
  end
end
