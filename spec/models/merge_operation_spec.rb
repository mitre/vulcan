# frozen_string_literal: true

require 'rails_helper'

# vulcan-v3.x-480.7 §17.3: one row per field-write during a merge so
# surgical undo can revert merge B's changes without touching A or C.
RSpec.describe MergeOperation do
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
      entity_type: 'rule',
      entity_id: 42,
      entity_key: 'SV-230221',
      operation: 'update',
      source: 'theirs'
    }.merge(overrides)
  end

  describe 'validations' do
    it 'requires entity_type, entity_id, entity_key, operation, source' do
      op = described_class.new(
        component_sync_event: sync_event,
        entity_type: nil, entity_id: nil, entity_key: nil, operation: nil, source: nil
      )
      expect(op).not_to be_valid
      %i[entity_type entity_id entity_key operation source].each do |attr|
        expect(op.errors[attr]).to be_present, "expected :#{attr} error"
      end
    end

    it 'rejects unknown operation' do
      expect(described_class.new(valid_attrs(operation: 'bogus'))).not_to be_valid
    end

    it 'rejects unknown source' do
      expect(described_class.new(valid_attrs(source: 'bogus'))).not_to be_valid
    end

    it 'is valid with the required attributes and enum membership' do
      expect(described_class.new(valid_attrs)).to be_valid
    end
  end
end
