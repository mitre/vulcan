# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TriageResponseTemplate do
  let_it_be(:project) { create(:project) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  def attrs(overrides = {})
    { project: project, created_by: user, name: 'Generalize text', body: "We'll generalize the check and fix text." }.merge(overrides)
  end

  it 'is valid with name + body + project + created_by' do
    expect(described_class.new(attrs)).to be_valid
  end

  it 'requires a name' do
    t = described_class.new(attrs(name: nil))
    expect(t).not_to be_valid
    expect(t.errors[:name]).to be_present
  end

  it 'requires a body' do
    t = described_class.new(attrs(body: nil))
    expect(t).not_to be_valid
    expect(t.errors[:body]).to be_present
  end

  it 'caps name length at 200' do
    t = described_class.new(attrs(name: 'a' * 201))
    expect(t).not_to be_valid
  end

  it 'enforces unique name per project (case-insensitive)' do
    described_class.create!(attrs(name: 'Generalize text'))
    dup = described_class.new(attrs(name: 'generalize TEXT'))
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to be_present
  end

  it 'allows the same name across different projects' do
    described_class.create!(attrs(name: 'Generalize text'))
    other = described_class.new(attrs(project: other_project, name: 'Generalize text'))
    expect(other).to be_valid
  end
end
