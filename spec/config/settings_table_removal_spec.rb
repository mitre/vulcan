# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'settings table cleanup' do
  # The `settings` table was used by a previous gem (rails-settings-cached)
  # and removed from schema.rb. A migration must exist to drop it so that
  # existing deployments upgrading via `db:migrate` don't retain an orphaned table.

  it 'schema.rb does not contain a settings table' do
    schema = Rails.root.join('db/schema.rb').read
    expect(schema).not_to match(/create_table "settings"/)
  end

  it 'a migration exists to drop the settings table' do
    migrations = Rails.root.glob('db/migrate/*drop*settings*')
    expect(migrations).not_to be_empty,
                              'Expected a migration to drop the orphaned settings table for existing deployments'
  end
end
