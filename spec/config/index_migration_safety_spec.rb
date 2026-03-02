# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'index migration safety' do
  # GIN and composite indexes on large tables acquire exclusive write locks.
  # Migrations must use disable_ddl_transaction! + algorithm: :concurrently
  # to avoid blocking writes during deployment.

  let(:trigram_migration) { Rails.root.join('db/migrate/20260201000002_add_trigram_indexes_for_search.rb').read }
  let(:severity_migration) { Rails.root.join('db/migrate/20260209232046_add_severity_count_indexes_to_base_rules.rb').read }

  describe 'trigram GIN index migration' do
    it 'disables DDL transaction' do
      expect(trigram_migration).to include('disable_ddl_transaction!'),
                                   'GIN index migration must use disable_ddl_transaction! to allow CONCURRENTLY'
    end

    it 'creates indexes concurrently' do
      expect(trigram_migration).to match(/algorithm:\s*:concurrently/),
                                   'GIN indexes must be created CONCURRENTLY to avoid write locks'
    end
  end

  describe 'severity count composite index migration' do
    it 'disables DDL transaction' do
      expect(severity_migration).to include('disable_ddl_transaction!'),
                                    'Composite index migration must use disable_ddl_transaction!'
    end

    it 'creates indexes concurrently' do
      expect(severity_migration).to match(/algorithm:\s*:concurrently/),
                                    'Composite indexes on large tables must be created CONCURRENTLY'
    end
  end
end
