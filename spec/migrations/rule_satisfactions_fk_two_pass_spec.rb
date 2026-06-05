# frozen_string_literal: true

require 'rails_helper'

# Regression guard for the 2-pass Strong Migrations FK pattern on
# rule_satisfactions. The table was created without DB-level FK
# constraints (db/migrate/20211103190520_create_rule_satisfactions.rb),
# so a satisfaction row referencing a non-existent rule on either side
# could persist as a dangling bigint — silently mis-routed during
# component sync merge (see v2-480.13 / expert review finding F2).
#
# Both columns get FKs with on_delete: :cascade. Unlike reviews
# (vulcan-cascade-rails-owns), this is a join-table modeled as HABTM
# with no Rails-side callbacks and no audited gem hooks — cascade is
# the semantically right cleanup mode when a parent rule disappears.
#
# Encodes the END STATE invariant: the FK exists, cascades on parent
# delete, and is validated.
RSpec.describe 'rule_satisfactions FK 2-pass' do
  let(:foreign_keys) { ActiveRecord::Base.connection.foreign_keys(:rule_satisfactions) }

  describe 'rule_id → base_rules.id' do
    let(:fk) { foreign_keys.find { |f| f.column == 'rule_id' } }

    it 'has a foreign key constraint' do
      expect(fk).to be_present
    end

    it 'targets base_rules' do
      expect(fk.to_table).to eq('base_rules')
    end

    it 'uses on_delete: :cascade (HABTM join table, no Rails callbacks to preserve)' do
      expect(fk.on_delete).to eq(:cascade)
    end

    it 'is validated in Postgres (convalidated = true)' do
      constraint_name = fk.options[:name] || fk.name
      result = ActiveRecord::Base.connection.exec_query(
        'SELECT convalidated FROM pg_constraint WHERE conname = $1',
        'kea-fk-validated',
        [constraint_name]
      )
      expect(result.first['convalidated']).to be true
    end
  end

  describe 'satisfied_by_rule_id → base_rules.id' do
    let(:fk) { foreign_keys.find { |f| f.column == 'satisfied_by_rule_id' } }

    it 'has a foreign key constraint' do
      expect(fk).to be_present
    end

    it 'targets base_rules' do
      expect(fk.to_table).to eq('base_rules')
    end

    it 'uses on_delete: :cascade' do
      expect(fk.on_delete).to eq(:cascade)
    end

    it 'is validated in Postgres (convalidated = true)' do
      constraint_name = fk.options[:name] || fk.name
      result = ActiveRecord::Base.connection.exec_query(
        'SELECT convalidated FROM pg_constraint WHERE conname = $1',
        'kea-fk-validated',
        [constraint_name]
      )
      expect(result.first['convalidated']).to be true
    end
  end
end
