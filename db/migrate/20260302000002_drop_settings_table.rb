# frozen_string_literal: true

# Drops the orphaned `settings` table left behind when rails-settings-cached
# was replaced by mitre-settingslogic (YAML-based config). The table was removed
# from schema.rb but never via a migration, so existing deployments upgrading
# through `db:migrate` would still have it.
class DropSettingsTable < ActiveRecord::Migration[8.0]
  def up
    drop_table :settings, if_exists: true
  end

  def down
    create_table :settings do |t|
      t.string :var, null: false
      t.text :value
      t.timestamps
      t.index :var, unique: true, name: 'index_settings_on_var'
    end
  end
end
