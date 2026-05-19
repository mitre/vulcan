# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/seed_helpers'

# This spec verifies the seed pipeline works correctly by running seeds
# into a clean database and checking the results. It uses the :truncation
# strategy instead of transactions so seed data persists across examples.
#
# IMPORTANT: Tagged :seed_pipeline so it is excluded from parallel_rspec runs.
# The truncation strategy in before(:all) corrupts other parallel test databases.
#
# Run standalone: bundle exec rspec spec/seeds/seed_pipeline_spec.rb --tag seed_pipeline
# Or via rake:    rails dev:verify (uses SeedHelpers.verify! for the same checks)
RSpec.describe 'seed pipeline', :seed_pipeline, type: :model do
  before(:all) do
    Rails.application.reload_routes!
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    Rails.application.load_seed
  end

  after(:all) do
    DatabaseCleaner.clean
    DatabaseCleaner.strategy = :transaction
  end

  describe 'record counts' do
    it 'has at least 14 users (admin + 3 role-tier + 10 filler)' do
      expect(User.count).to be >= 14
    end

    it 'has exactly 5 projects' do
      expect(Project.count).to eq(5)
    end

    it 'has 4 SRGs' do
      expect(SecurityRequirementsGuide.count).to eq(4)
    end

    it 'has 4 STIGs' do
      expect(Stig.count).to eq(4)
    end

    it 'has at least 8 components' do
      expect(Component.count).to be >= 8
    end
  end

  describe 'RBAC coverage' do
    it 'every demo project has viewer, author, reviewer, and admin memberships' do
      demo_project_names = ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform']
      Project.where(name: demo_project_names).find_each do |p|
        roles = p.memberships.pluck(:role).uniq.sort
        expect(roles).to include('admin', 'author', 'reviewer', 'viewer'),
                         "Project '#{p.name}' missing role tiers — has: #{roles.inspect}"
      end
    end
  end

  describe 'comment seed data' do
    it 'has at least 18 top-level comments' do
      top_level = Review.where(action: 'comment', responding_to_review_id: nil).count
      expect(top_level).to be >= 18
    end

    it 'has at least 5 replies' do
      replies = Review.where(action: 'comment').where.not(responding_to_review_id: nil).count
      expect(replies).to be >= 5
    end

    it 'covers key triage statuses' do
      statuses = Review.where(action: 'comment').distinct.pluck(:triage_status).compact
      %w[pending concur non_concur informational withdrawn].each do |s|
        expect(statuses).to include(s), "Missing triage status '#{s}' — found: #{statuses.inspect}"
      end
    end
  end

  describe 'idempotency' do
    it 'second seed run does not change record counts' do
      before_counts = SeedHelpers.status_report
      Rails.application.load_seed
      after_counts = SeedHelpers.status_report
      expect(after_counts).to eq(before_counts),
                              "Counts changed after second seed:\n  before: #{before_counts}\n  after:  #{after_counts}"
    end
  end
end
