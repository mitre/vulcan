# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditBlueprint do
  let_it_be(:user) { create(:user, name: 'Audit User') }
  let_it_be(:project) { create(:project, name: 'Audit Project') }

  let_it_be(:audit) do
    Audited.audit_class.create!(
      auditable: user,
      user: user,
      action: 'update',
      audited_changes: { 'name' => ['Old Name', 'Audit User'] },
      comment: 'Updated name'
    )
  end

  subject(:result) { described_class.render_as_json(audit) }

  it 'includes id' do
    expect(result['id']).to eq(audit.id)
  end

  it 'includes action' do
    expect(result['action']).to eq('update')
  end

  it 'includes auditable_type and auditable_id' do
    expect(result['auditable_type']).to eq('User')
    expect(result['auditable_id']).to eq(user.id)
  end

  it 'includes name from username' do
    expect(result['name']).to eq('Audit User')
  end

  it 'includes audited_name from audited_username' do
    expect(result['audited_name']).to eq('Audit User')
  end

  it 'includes comment' do
    expect(result['comment']).to eq('Updated name')
  end

  it 'includes created_at' do
    expect(result).to have_key('created_at')
  end

  it 'formats audited_changes as array of field/prev_value/new_value' do
    changes = result['audited_changes']
    expect(changes).to be_an(Array)
    expect(changes.length).to eq(1)

    change = changes.first
    expect(change['field']).to eq('name')
    expect(change['prev_value']).to eq('Old Name')
    expect(change['new_value']).to eq('Audit User')
  end

  it 'has consistent string keys at all nesting levels' do
    expect(result.keys).to all(be_a(String))
    changes = result['audited_changes']
    changes.each do |change|
      expect(change.keys).to all(be_a(String))
    end
  end

  describe 'create action (single value, not array)' do
    let_it_be(:create_audit) do
      Audited.audit_class.create!(
        auditable: project,
        user: user,
        action: 'create',
        audited_changes: { 'name' => 'Brand New' },
        username: user.name
      )
    end

    it 'sets prev_value to nil and new_value to the single value' do
      result = described_class.render_as_json(create_audit)
      change = result['audited_changes'].first
      expect(change['prev_value']).to be_nil
      expect(change['new_value']).to eq('Brand New')
    end
  end

  describe 'shape parity with Audit#format' do
    it 'produces the same keys as Audit#format' do
      format_keys = audit.format.keys.map(&:to_s).sort
      blueprint_keys = result.keys.sort
      expect(blueprint_keys).to eq(format_keys)
    end
  end
end
