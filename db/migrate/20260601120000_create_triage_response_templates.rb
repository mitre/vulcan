# frozen_string_literal: true

# Project-scoped canned responses for triage replies. Author+ select from
# a dropdown to populate the response textarea; admin manages the template
# library. Unique-name-per-project enforced at the DB level so a stale UI
# can't create two templates that look the same in the dropdown.
class CreateTriageResponseTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :triage_response_templates do |t|
      t.references :project, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false, limit: 200
      t.text :body, null: false
      t.timestamps
    end
    add_index :triage_response_templates, [:project_id, :name], unique: true, name: 'idx_triage_templates_unique_name_per_project'
  end
end
