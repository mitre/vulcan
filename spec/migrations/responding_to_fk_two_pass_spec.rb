# frozen_string_literal: true

require 'rails_helper'

# regression guard for the 2-pass
# Strong Migrations FK pattern on reviews.responding_to_review_id.
#
# Pre-fix: 20260502080000_change_review_responding_to_fk_to_restrict
# ran `add_foreign_key validate: false` AND `validate_foreign_key`
# in the SAME ddl_transaction. On a production-sized reviews table
# the validate scan holds ACCESS EXCLUSIVE for the duration —
# write-blocking window.
#
# Post-fix: the validate is split into a paired migration
# (20260502080001_validate_review_responding_to_fk) marked with
# `disable_ddl_transaction!` so the ACCESS EXCLUSIVE lock is held
# only briefly per affected row, not for the entire scan.
#
# This spec encodes the END STATE invariant — does not care which
# migration validated the FK, only that the FK exists, has the
# correct on_delete behavior, and is validated. Either the legacy
# 1-pass migration or the new 2-pass pair leaves the same end state.
RSpec.describe 'reviews.responding_to_review_id FK 2-pass' do
  let(:fk) do
    ActiveRecord::Base.connection.foreign_keys(:reviews).find do |f|
      f.column == 'responding_to_review_id'
    end
  end

  it 'has a foreign key constraint' do
    expect(fk).to be_present
  end

  it 'targets the reviews table' do
    expect(fk.to_table).to eq('reviews')
  end

  it 'uses on_delete: :restrict (Rails owns cascade — see vulcan-cascade-rails-owns memory)' do
    expect(fk.on_delete).to eq(:restrict)
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
