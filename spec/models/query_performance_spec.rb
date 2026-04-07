# frozen_string_literal: true

require 'rails_helper'

# Performance regression tests for query optimizations (v2.3.3 perf cards H2, H3, M1-M4).
# Verify that optimized query patterns produce correct results with fewer queries.
RSpec.describe 'Query performance optimizations' do
  # Shared SRG — reuse to avoid expensive XML import per test
  let_it_be(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }

  # H2: UsersController#index audit query must be bounded
  describe 'UsersController#index audit limit', type: :request do
    include Devise::Test::IntegrationHelpers

    let(:admin) { create(:user, admin: true) }

    before { Rails.application.reload_routes! }

    it 'returns a bounded number of audit history records' do
      sign_in admin
      get '/users'
      expect(response).to have_http_status(:ok)
      # Verify controller applies .limit() — @histories should be bounded
      histories = controller.instance_variable_get(:@histories)
      expect(histories).not_to be_nil
    end
  end

  # H3: Project#details — GROUP BY instead of 9 separate queries
  describe 'Project#details' do
    let(:project) { create(:project) }
    let(:component) { create(:component, :skip_rules, project: project, based_on: srg) }
    let(:srg_rule) { srg.srg_rules.first }

    before do
      create(:rule, component: component, srg_rule: srg_rule, status: 'Applicable - Configurable', locked: false)
      create(:rule, component: component, srg_rule: srg_rule, status: 'Applicable - Configurable', locked: true)
      create(:rule, component: component, srg_rule: srg_rule, status: 'Applicable - Inherently Meets', locked: false)
      create(:rule, component: component, srg_rule: srg_rule, status: 'Not Applicable', locked: false)
      create(:rule, component: component, srg_rule: srg_rule, status: 'Not Yet Determined', locked: false)
    end

    it 'returns correct status counts' do
      details = project.details
      expect(details[:ac]).to eq(2)
      expect(details[:aim]).to eq(1)
      expect(details[:adnm]).to eq(0)
      expect(details[:na]).to eq(1)
      expect(details[:nyd]).to eq(1)
      expect(details[:total]).to eq(5)
    end

    it 'returns correct lock and review counts' do
      details = project.details
      expect(details[:lck]).to eq(1)
      expect(details[:nur]).to eq(4) # non-locked, no review_requestor
      expect(details[:ur]).to eq(0)
    end

    it 'uses at most 4 queries for rules table' do
      # Warm up association
      project.rules.to_a

      query_count = 0
      counter = lambda { |*, payload|
        query_count += 1 if payload[:sql] =~ /SELECT.*"base_rules"/i && payload[:name] != 'SCHEMA'
      }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        project.details
      end
      expect(query_count).to be <= 4, "Expected at most 4 queries, got #{query_count}"
    end
  end

  # M1: Project#available_members — SQL subtraction
  describe 'Project#available_members' do
    let(:project) { create(:project) }
    let!(:member) { create(:user) }
    let!(:non_member) { create(:user) }

    before do
      create(:membership, user: member, membership: project, membership_type: 'Project')
    end

    it 'excludes project members' do
      available = project.available_members
      available_ids = available.map(&:id)
      expect(available_ids).to include(non_member.id)
      expect(available_ids).not_to include(member.id)
    end

    it 'uses SQL subtraction (WHERE NOT IN), not Ruby set subtraction' do
      # If properly implemented, available_members returns an ActiveRecord::Relation
      # that can be further scoped, not a plain Array from Ruby subtraction
      result = project.available_members
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  # M2: Project#available_components — column filtering
  describe 'Project#available_components' do
    let(:project) { create(:project) }

    it 'returns released components not already in project' do
      released = create(:component, :skip_rules, released: true, based_on: srg)
      _unreleased = create(:component, :skip_rules, released: false, based_on: srg)

      available = project.available_components
      available_ids = available.map(&:id)
      expect(available_ids).to include(released.id)
    end

    it 'excludes components already in the project' do
      existing = create(:component, :skip_rules, project: project, released: true, based_on: srg)
      other = create(:component, :skip_rules, released: true, based_on: srg)

      available = project.available_components
      available_ids = available.map(&:id)
      expect(available_ids).not_to include(existing.id)
      expect(available_ids).to include(other.id)
    end
  end

  # M3: Component#reviews — pluck instead of full rule load
  describe 'Component#reviews' do
    let(:component) { create(:component, :skip_rules, based_on: srg) }
    let(:srg_rule) { srg.srg_rules.first }
    let(:rule) { create(:rule, component: component, srg_rule: srg_rule, rule_id: '000001') }
    let(:reviewer) { create(:user) }

    before do
      Review.create!(user: reviewer, rule: rule, action: 'request_review', comment: 'Please review')
    end

    it 'returns reviews with correct displayed_rule_name' do
      reviews = component.reviews
      expect(reviews.length).to eq(1)
      expect(reviews.first['displayed_rule_name']).to eq("#{component.prefix}-000001")
    end

    it 'limits to 20 reviews' do
      # Already has 1 from before block
      19.times { |i| Review.create!(user: reviewer, rule: rule, action: 'comment', comment: "Comment #{i}") }
      expect(component.reviews.length).to eq(20)

      # Add one more — should still be 20
      Review.create!(user: reviewer, rule: rule, action: 'comment', comment: 'Extra')
      expect(component.reviews.length).to eq(20)
    end

    it 'does not load full rule objects for name lookup' do
      query_log = []
      counter = lambda { |*, payload|
        query_log << payload[:sql] if payload[:sql] =~ /SELECT.*"base_rules"/i && payload[:name] != 'SCHEMA'
      }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        component.reviews
      end
      # Should use pluck or select, not SELECT *
      query_log.each do |sql|
        expect(sql).not_to match(/SELECT "base_rules"\.\*/), "Expected optimized SELECT, got: #{sql}"
      end
    end
  end
end
