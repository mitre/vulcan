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
    # Fresh-seed population is deterministic: 1 admin + 3 role-tier +
    # 8 community personas + requester + 2 API test users. The filler-user
    # block never fires on a fresh seed (personas alone push the non-demo
    # count past its threshold).
    it 'has exactly 15 users' do
      expect(User.count).to eq(15)
    end

    it 'has exactly 6 projects' do
      expect(Project.count).to eq(6)
    end

    # 4 XCCDF files in db/seeds/srgs + the Container SRG Test dataset SRG
    it 'has 5 SRGs' do
      expect(SecurityRequirementsGuide.count).to eq(5)
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
      demo_projects = Project.where(name: demo_project_names)
      expect(demo_projects.count).to eq(4)
      demo_projects.find_each do |p|
        roles = p.memberships.pluck(:role).uniq.sort
        expect(roles).to include('admin', 'author', 'reviewer', 'viewer'),
                         "Project '#{p.name}' missing role tiers — has: #{roles.inspect}"
      end
    end
  end

  describe 'API test users' do
    it 'creates api-admin@example.com as a site admin and api-viewer@example.com as a member-tier user' do
      api_admin = User.find_by(email: 'api-admin@example.com')
      api_viewer = User.find_by(email: 'api-viewer@example.com')
      expect(api_admin&.admin).to be(true), 'api-admin@example.com missing or not a site admin'
      expect(api_viewer&.admin).to be(false), 'api-viewer@example.com missing or unexpectedly a site admin'
      expect(api_admin.confirmed?).to be(true)
      expect(api_viewer.confirmed?).to be(true)
    end

    it 'gives api-viewer viewer membership on all four demo projects' do
      api_viewer = User.find_by(email: 'api-viewer@example.com')
      demo_projects = Project.where(name: ['Photon 3', 'Photon 4', 'vSphere 7.0', 'Container Platform'])
      expect(demo_projects.count).to eq(4)
      demo_projects.find_each do |p|
        role = p.memberships.find_by(user: api_viewer)&.role
        expect(role).to eq('viewer'), "api-viewer membership on '#{p.name}' expected viewer, got #{role.inspect}"
      end
    end
  end

  describe 'access request persona' do
    # requester@example.com exists to exercise the request-access flow:
    # a pending request means deliberately NOT a member of that project.
    # Guards the 05_memberships/09_access_requests ordering — the all-users
    # membership loop must never re-grant what a pending request is asking for.
    it 'requester has a pending vSphere request and no vSphere membership' do
      requester = User.find_by(email: 'requester@example.com')
      vsphere = Project.find_by(name: 'vSphere 7.0')
      expect(requester).to be_present
      expect(ProjectAccessRequest.exists?(user: requester, project: vsphere)).to be(true)
      expect(Membership.exists?(user: requester, membership: vsphere)).to be(false)
    end
  end

  describe 'comment seed data' do
    it 'has at least 18 top-level comments' do
      top_level = Review.where(action: Review::ACTION_COMMENT, responding_to_review_id: nil).count
      expect(top_level).to be >= 18
    end

    it 'has at least 5 replies' do
      replies = Review.where(action: Review::ACTION_COMMENT).where.not(responding_to_review_id: nil).count
      expect(replies).to be >= 5
    end

    it 'covers key triage statuses' do
      statuses = Review.where(action: Review::ACTION_COMMENT).distinct.pluck(:triage_status).compact
      %w[pending concur non_concur informational withdrawn].each do |s|
        expect(statuses).to include(s), "Missing triage status '#{s}' — found: #{statuses.inspect}"
      end
    end

    it 'all reply threading references are valid (no orphaned responding_to)' do
      orphaned = Review.where(action: Review::ACTION_COMMENT)
                       .where.not(responding_to_review_id: nil)
                       .where.not(responding_to_review_id: Review.select(:id))
      expect(orphaned.count).to eq(0),
                                "Found #{orphaned.count} replies pointing to nonexistent parent reviews: #{orphaned.pluck(:id).inspect}"
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
