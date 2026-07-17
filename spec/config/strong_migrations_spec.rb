# frozen_string_literal: true

require 'rails_helper'

# Guards that strong_migrations is installed AND actively enforcing — not
# merely present. A migration that performs a lock-heavy operation (adding an
# index non-concurrently blocks writes for the duration of the build) must be
# rejected before it can run, so unsafe migrations are caught in dev/CI instead
# of on a production table.
RSpec.describe 'strong_migrations enforcement' do
  describe 'configuration' do
    it 'marks migrations through the adoption point as safe (does not police history)' do
      # The latest migration that existed when the gem was adopted. Everything
      # at or before this is grandfathered; everything after is checked.
      expect(StrongMigrations.start_after).to eq(20_260_713_220_000)
    end

    it 'targets the production Postgres major version for accurate checks' do
      expect(StrongMigrations.target_version).to eq(18)
    end
  end

  describe 'enforcement' do
    # An index added non-concurrently on an existing table — the canonical
    # unsafe operation. strong_migrations raises before it executes.
    let(:unsafe_migration) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          add_index :users, :email
        end
      end
    end

    it 'rejects a non-concurrent add_index with StrongMigrations::UnsafeMigration' do
      expect do
        ActiveRecord::Migration.suppress_messages { unsafe_migration.migrate(:up) }
      end.to raise_error(StrongMigrations::UnsafeMigration, /concurrently/)
    end
  end
end
