# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/seed_context'

RSpec.describe SeedContext do
  subject(:ctx) { described_class.new }

  before do
    Rails.application.reload_routes!
  end

  let!(:srg) { SeedHelpers.seed_xccdf(Rails.root.join('db/seeds/srgs').glob('*GPOS*.xml').first) }
  let!(:admin) { create(:user, name: 'Demo Admin', email: 'admin@example.com', admin: true) }
  let!(:viewer) { create(:user, name: 'Demo Viewer', email: 'viewer@example.com') }
  let!(:author) { create(:user, name: 'Demo Author', email: 'author@example.com') }
  let!(:project) { create(:project, name: 'Container Platform') }
  let!(:component) { create(:component, project: project, name: 'Container Platform', based_on: srg) }

  describe '#initialize' do
    it 'loads all users indexed by email' do
      expect(ctx.users['admin@example.com']).to eq(admin)
      expect(ctx.users['viewer@example.com']).to eq(viewer)
      expect(ctx.users['author@example.com']).to eq(author)
    end

    it 'loads all projects indexed by name' do
      expect(ctx.projects['Container Platform']).to eq(project)
    end

    it 'loads all components indexed by name' do
      expect(ctx.components['Container Platform']).to eq(component)
    end
  end

  describe '#user' do
    it 'resolves by email key' do
      expect(ctx.user('admin@example.com')).to eq(admin)
    end

    it 'resolves by symbol key from DEMO_ROLE_USERS' do
      expect(ctx.user(:viewer)).to eq(viewer)
    end

    it 'falls back to admin for unknown keys' do
      expect(ctx.user(:nonexistent)).to eq(admin)
    end
  end

  describe '#project' do
    it 'resolves by name' do
      expect(ctx.project('Container Platform')).to eq(project)
    end

    it 'returns nil for unknown projects' do
      expect(ctx.project('Nonexistent')).to be_nil
    end
  end

  describe '#component' do
    it 'resolves by name' do
      expect(ctx.component('Container Platform')).to eq(component)
    end
  end

  describe '#rules_for' do
    it 'returns rules indexed by position for a component' do
      rules = ctx.rules_for(component)
      expect(rules).to be_a(Hash)
      expect(rules.values).to all(be_a(Rule))
    end
  end
end
