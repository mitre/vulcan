# frozen_string_literal: true

require 'rails_helper'

# Proves let_it_be records get fresh AR instances per example (refind: true global default).
# Without refind, Test A's in-memory mutations leak into Test B even though the DB row is
# rolled back by the transactional fixture SAVEPOINT. See test-prof docs:
# "reload may not be enough, 'cause it doesn't reset associations"
RSpec.describe 'let_it_be isolation (refind: true global default)' do
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }

  it 'example A: mutates the component name' do
    component.update!(name: 'MUTATED BY EXAMPLE A')
    expect(component.name).to eq('MUTATED BY EXAMPLE A')
  end

  it 'example B: sees the original component name (not the mutation from A)' do
    expect(component.name).not_to eq('MUTATED BY EXAMPLE A')
  end

  it 'example C: mutates a rule via the association' do
    rule = component.rules.first
    rule.update!(title: 'MUTATED BY EXAMPLE C', audit_comment: 'test')
    expect(rule.title).to eq('MUTATED BY EXAMPLE C')
  end

  it 'example D: sees the original rule title via association (not the mutation from C)' do
    rule = component.rules.first
    expect(rule.title).not_to eq('MUTATED BY EXAMPLE C')
  end
end
