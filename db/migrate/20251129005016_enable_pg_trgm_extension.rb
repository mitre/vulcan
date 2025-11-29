class EnablePgTrgmExtension < ActiveRecord::Migration[8.0]
  def up
    # Enable PostgreSQL trigram extension for fuzzy/typo-tolerant search
    execute 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'
  end

  def down
    # Safe to leave extension enabled - other features might use it
    execute 'DROP EXTENSION IF EXISTS pg_trgm;'
  end
end
