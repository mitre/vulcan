class CreateControls < ActiveRecord::Migration[5.1]
  def change
    create_table :project_controls do |t|
      t.string "title"
      t.string "description"
      t.float "impact"
      t.string "code"
      t.string "control_id"
      t.string "sl_ref"
      t.string "sl_line"
      t.text "tag"
      t.text "checktext"
      t.text "fixtext"
      t.text "justification"
      t.text "applicability"
      t.text "srg_title_id"
      t.references(:projects, index: true)
    end
  end
end
