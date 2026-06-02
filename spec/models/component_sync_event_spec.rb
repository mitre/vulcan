# frozen_string_literal: true

require 'rails_helper'

# (Phase 2a): ComponentSyncEvent is the per-merge audit
# row that anchors snapshot_path, archive_hash, resolution_log, and
# downstream merge_operations + merge_quarantine entries. Two-direction FK:
# every event belongs to a Component, and sync_id is the natural key that
# parent_sync_id references for chained syncs.
RSpec.describe ComponentSyncEvent do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  def valid_attrs(overrides = {})
    {
      component: component,
      sync_id: SecureRandom.uuid,
      source: 'manual',
      direction: 'inbound',
      created_at: Time.current
    }.merge(overrides)
  end

  describe 'validations' do
    it 'validates presence of sync_id and component' do
      event = described_class.new(valid_attrs(component: nil, sync_id: nil))
      expect(event).not_to be_valid
      expect(event.errors[:sync_id]).to be_present
      expect(event.errors[:component]).to be_present
    end

    it 'is valid with the required attributes' do
      expect(described_class.new(valid_attrs)).to be_valid
    end
  end
end
