# frozen_string_literal: true

require 'rails_helper'

# Tests the backfill that flags pre-recognition rows of the three
# DISA-published core SRGs. Must be idempotent (re-run matches nothing)
# and must never touch derived SRGs or already-flagged rows. Recognition
# is derived from DISA's published identity, so down is intentionally
# irreversible.
RSpec.describe 'BackfillCoreSrgRecognition migration' do
  let(:migration_class) do
    require Rails.root.join('db/migrate/20260730004236_backfill_core_srg_recognition')
    BackfillCoreSrgRecognition
  end

  # Simulate rows created BEFORE recognition existed: create (recognition
  # flags the core id), then force the column back to the legacy state.
  let!(:legacy_core) do
    create(:security_requirements_guide, :skip_rules,
           srg_id: 'Operating_System_Core', title: 'Operating System Core Security Requirements Guide')
      .tap { |srg| srg.update_columns(core: false) }
  end
  let!(:derived) { create(:security_requirements_guide, :skip_rules) }

  it 'flags a pre-recognition core row' do
    expect { migration_class.new.up }
      .to change { legacy_core.reload.core }.from(false).to(true)
  end

  it 'leaves derived SRGs untouched' do
    migration_class.new.up
    expect(derived.reload.core).to be false
  end

  it 'is idempotent — a second run matches zero rows and changes nothing' do
    migration_class.new.up
    expect { migration_class.new.up }
      .not_to(change { SecurityRequirementsGuide.order(:id).pluck(:id, :core) })
  end

  it 'is intentionally irreversible — down raises' do
    expect { migration_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
