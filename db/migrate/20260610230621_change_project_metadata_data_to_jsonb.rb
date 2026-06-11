# frozen_string_literal: true

# project_metadata.data was JSON; migrate to JSONB for parity with
# component_metadata (20260526120000) — binary comparison, indexable,
# no re-parse on read. No consumer depends on json text semantics.
class ChangeProjectMetadataDataToJsonb < ActiveRecord::Migration[8.0]
  def up
    change_column :project_metadata, :data, :jsonb, using: 'data::jsonb'
  end

  def down
    change_column :project_metadata, :data, :json, using: 'data::json'
  end
end
