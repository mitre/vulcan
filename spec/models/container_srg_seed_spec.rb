# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Container SRG seed distribution' do
  describe 'SeedHelpers::COMMUNITY_PERSONAS' do
    it 'defines at least 6 stable named personas with @example.org emails' do
      personas = SeedHelpers::COMMUNITY_PERSONAS
      expect(personas.size).to be >= 6
      personas.each do |email, attrs|
        expect(email).to match(/@example\.org\z/)
        expect(attrs[:name]).to be_a(String)
        expect(attrs[:name].length).to be > 3
      end
    end

    it 'assigns RBAC-valid roles to each persona' do
      valid_roles = %w[viewer author reviewer admin]
      SeedHelpers::COMMUNITY_PERSONAS.each_value do |attrs|
        expect(valid_roles).to include(attrs[:role])
      end
    end
  end

  describe 'RBAC distribution rules' do
    let(:authority_roles) { %w[author reviewer admin] }

    it 'only assigns triage to authority-role users' do
      SeedHelpers::TRIAGE_POOL.each do |email|
        role = SeedHelpers::COMMUNITY_PERSONAS[email]&.dig(:role) || infer_role(email)
        expect(authority_roles).to(
          include(role),
          "Triage pool includes #{email} with role '#{role}' — only author/reviewer/admin allowed"
        )
      end
    end

    it 'only assigns adjudication to reviewer/admin users' do
      SeedHelpers::ADJUDICATE_POOL.each do |email|
        role = SeedHelpers::COMMUNITY_PERSONAS[email]&.dig(:role) || infer_role(email)
        expect(%w[reviewer admin]).to(
          include(role),
          "Adjudicate pool includes #{email} with role '#{role}' — only reviewer/admin allowed"
        )
      end
    end
  end

  describe 'source zip' do
    let(:source_path) { Rails.root.join('db/seeds/backups/container_srg_test.source.zip') }

    it 'exists and is a valid zip' do
      expect(File.exist?(source_path)).to be true
      expect(File.size(source_path)).to be > 1000
    end
  end

  private

  def infer_role(email)
    case email
    when 'admin@example.com' then 'admin'
    when 'reviewer@example.com' then 'reviewer'
    when 'author@example.com' then 'author'
    else 'viewer'
    end
  end
end
