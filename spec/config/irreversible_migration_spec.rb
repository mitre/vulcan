# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'irreversible data migrations' do
  # Data migrations that cannot be reversed must raise
  # ActiveRecord::IrreversibleMigration in their `down` method.
  # A silent no-op tricks engineers into thinking a rollback worked.

  include ConfigFileHelpers

  it 'StripSatisfactionTextFromVendorComments raises on rollback' do
    migration_content = Rails.root.join(
      'db/migrate/20260214000023_strip_satisfaction_text_from_vendor_comments.rb'
    ).read

    expect(migration_content).to include('IrreversibleMigration'),
                                 'Data migration down method must raise ActiveRecord::IrreversibleMigration'
  end
end
