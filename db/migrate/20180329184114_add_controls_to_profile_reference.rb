class AddControlsToProfileReference < ActiveRecord::Migration[5.1]
  def change
    add_reference :controls, :profile, foreign_key: true
  end
end
