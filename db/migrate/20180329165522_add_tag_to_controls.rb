class AddTagToControls < ActiveRecord::Migration[5.1]
  def change
    add_reference :tags, :control, foreign_key: true
  end
end
