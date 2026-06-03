# frozen_string_literal: true

require 'rails_helper'

# archive records that failed merge validation
# land here with original_archive_data intact so they can be retried after
# the underlying issue is fixed. Table name is 'merge_quarantine'
# (collective); each row is a quarantined record.
RSpec.describe MergeQuarantineRecord do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  let_it_be(:sync_event) do
    ComponentSyncEvent.create!(
      component: component, sync_id: SecureRandom.uuid,
      source: 'manual', direction: 'inbound', created_at: Time.current
    )
  end

  def valid_attrs(overrides = {})
    {
      component_sync_event: sync_event,
      entity_type: 'review',
      entity_key: 'SV-230221|2026-04-15T00:00:00Z|d41d8cd9',
      quarantine_reason: 'cross-rule reply target not in archive',
      original_archive_data: { 'external_id' => 999, 'comment' => 'orphaned' }
    }.merge(overrides)
  end

  it 'uses the merge_quarantine table' do
    expect(described_class.table_name).to eq('merge_quarantine')
  end

  describe 'validations' do
    it 'requires entity_type, entity_key, quarantine_reason, original_archive_data' do
      rec = described_class.new(
        component_sync_event: sync_event,
        entity_type: nil, entity_key: nil, quarantine_reason: nil, original_archive_data: nil
      )
      expect(rec).not_to be_valid
      %i[entity_type entity_key quarantine_reason original_archive_data].each do |attr|
        expect(rec.errors[attr]).to be_present, "expected :#{attr} error"
      end
    end

    it 'is valid with the required attributes' do
      expect(described_class.new(valid_attrs)).to be_valid
    end
  end
end
