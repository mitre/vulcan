# frozen_string_literal: true

# vulcan-v3.x-480.6 §18.4: component_metadata.data was JSON; migrate to JSONB
# so we can index inside the blob and compare in binary form. JSON stores the
# raw text and re-parses on every read; JSONB is the right default for
# anything queried, indexed, or merged (the upcoming sync/merge pipeline needs
# JSONB for indexed lookups inside metadata).
class ChangeComponentMetadataDataToJsonb < ActiveRecord::Migration[8.0]
  def up
    change_column :component_metadata, :data, :jsonb, using: 'data::jsonb'
  end

  def down
    change_column :component_metadata, :data, :json, using: 'data::json'
  end
end
