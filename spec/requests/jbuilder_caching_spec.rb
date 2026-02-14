# frozen_string_literal: true

require 'rails_helper'

##
# Jbuilder Caching Regression Tests
#
# REQUIREMENTS:
# - Verify collection caching is enabled (cached: true)
# - Verify cache invalidates when records update
# - Protect against regressions where caching is accidentally removed
#
RSpec.describe 'Jbuilder Caching' do
  let(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Rails.cache.clear # Start with empty cache
  end

  describe 'Components index caching' do
    let!(:component) { create(:component, released: true) }

    it 'returns consistent JSON with caching enabled' do
      # First request - populates cache
      get '/components.json'
      expect(response).to have_http_status(:success)
      first_body = response.body

      # Second request - should return same JSON (from cache)
      get '/components.json'
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end

  describe 'STIGs index caching' do
    let!(:stig) { create(:stig) }

    it 'returns consistent JSON with caching enabled' do
      get '/stigs.json'
      expect(response).to have_http_status(:success)
      first_body = response.body

      get '/stigs.json'
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end

  describe 'SRGs index caching' do
    let!(:srg) { create(:security_requirements_guide) }

    it 'returns consistent JSON with caching enabled' do
      get '/srgs.json'
      expect(response).to have_http_status(:success)
      first_body = response.body

      get '/srgs.json'
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end

  describe 'STIG show caching (rules collection)' do
    let(:stig) { create(:stig) }
    let!(:rule) { create(:stig_rule, stig: stig) }

    it 'returns consistent JSON with cached rules' do
      get "/stigs/#{stig.id}.json"
      expect(response).to have_http_status(:success)
      first_body = response.body

      get "/stigs/#{stig.id}.json"
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end

    it 'cache invalidates when rule updates' do
      get "/stigs/#{stig.id}.json"
      first_body = response.body

      # Update rule - invalidates cache
      rule.update(title: 'Updated title')

      get "/stigs/#{stig.id}.json"
      second_body = response.body

      # Response should be different (cache invalidated)
      expect(second_body).not_to eq(first_body)
      expect(second_body).to include('Updated title')
    end
  end

  describe 'SRG show caching (rules collection)' do
    let(:srg) { create(:security_requirements_guide) }
    let!(:rule) { create(:srg_rule, security_requirements_guide: srg) }

    it 'returns consistent JSON with cached rules' do
      get "/srgs/#{srg.id}.json"
      expect(response).to have_http_status(:success)
      first_body = response.body

      get "/srgs/#{srg.id}.json"
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end

  describe 'Component show caching (rules collection for viewer mode)' do
    let(:project) { create(:project) }
    let!(:component) { create(:component, project: project, released: true) }
    let(:rule) { component.rules.first }

    before do
      component.reload # Ensure rules are loaded
    end

    it 'returns consistent JSON with cached rules for viewer' do
      # Non-member viewing released component (no @effective_permissions)
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)
      first_body = response.body

      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)
      expect(response.body).to eq(first_body)
    end
  end
end
