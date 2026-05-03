# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# - Login attempts are throttled to 5 per 60 seconds per IP
# - Login attempts are throttled to 5 per 60 seconds per email
# - File uploads are throttled to 10 per 60 seconds per IP
# - Throttled responses return 429 with a JSON error message

RSpec.describe 'Rack::Attack throttling' do
  before do
    Rails.application.reload_routes!
    # Create a fresh, isolated cache store for each test to prevent
    # cross-contamination from other specs in the same parallel worker
    @fresh_store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store = @fresh_store
    Rack::Attack.reset!
  end

  after do
    # Restore default cache and clear to prevent bleeding into other tests
    Rack::Attack.cache.store = Rails.cache
    Rack::Attack.reset!
  end

  describe 'login throttling' do
    it 'allows 5 login attempts then returns 429' do
      # Use unique IP per test run to avoid cross-test contamination
      test_ip = "192.168.#{rand(1..254)}.#{rand(1..254)}"

      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: "throttle-ip-#{i}-#{SecureRandom.hex(4)}@example.com", password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => test_ip }
        expect(response.status).not_to eq(429), "Request #{i + 1} was throttled unexpectedly"
      end

      # 6th attempt should be throttled
      post '/users/sign_in',
           params: { user: { email: "throttle-ip-final-#{SecureRandom.hex(4)}@example.com", password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => test_ip }
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Rate limited')
    end

    it 'throttles by email independently of IP' do
      # Use unique email per test run to avoid cross-test contamination
      target_email = "throttle-email-#{SecureRandom.hex(6)}@example.com"

      5.times do |i|
        post '/users/sign_in',
             params: { user: { email: target_email, password: 'wrong' } },
             headers: { 'REMOTE_ADDR' => "172.16.#{rand(1..254)}.#{i + 1}" }
      end

      # 6th attempt with same email from different IP should be throttled
      post '/users/sign_in',
           params: { user: { email: target_email, password: 'wrong' } },
           headers: { 'REMOTE_ADDR' => "172.16.#{rand(1..254)}.99" }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'comment-action throttling on POST /rules/:id/reviews' do
    let_it_be(:srg) do
      srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
      parsed = Xccdf::Benchmark.parse(srg_xml)
      s = SecurityRequirementsGuide.from_mapping(parsed)
      s.xml = srg_xml
      s.save!
      s
    end
    let_it_be(:project) { Project.create!(name: "Throttle Test #{SecureRandom.hex(4)}") }
    let_it_be(:component) do
      Component.create!(project: project, name: 'TestComp', title: 'TestComp',
                        version: 'V1R1', prefix: 'THRT-01', based_on: srg)
    end
    let(:rule) { component.rules.first }
    let(:viewer) { create(:user) }

    before do
      Membership.create!(user: viewer, membership: project, role: 'viewer')
      sign_in viewer
    end

    it 'allows the first 10 comment posts in a minute' do
      10.times do |i|
        post "/rules/#{rule.id}/reviews",
             params: { review: { action: 'comment', comment: "comment #{i}", component_id: component.id } },
             as: :json
        expect(response.status).not_to eq(429), "Request #{i + 1} unexpectedly throttled"
      end
    end

    it 'throttles the 11th comment post within a minute' do
      10.times do |i|
        post "/rules/#{rule.id}/reviews",
             params: { review: { action: 'comment', comment: "comment #{i}", component_id: component.id } },
             as: :json
      end

      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'comment', comment: 'eleventh', component_id: component.id } },
           as: :json
      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig('toast', 'title')).to eq('Rate limited')
    end

    it 'does not throttle non-comment review actions on the same endpoint' do
      # Promote to author so request_review passes the model-layer role gate.
      # Membership has a uniqueness validation (one role per user/project), so
      # update the existing viewer row rather than create a second.
      Membership.find_by!(user: viewer, membership: project).update!(role: 'author')

      # Burn the comment limit
      10.times do |i|
        post "/rules/#{rule.id}/reviews",
             params: { review: { action: 'comment', comment: "spam #{i}", component_id: component.id } },
             as: :json
      end

      # request_review on the same endpoint goes through (separate throttle key)
      post "/rules/#{rule.id}/reviews",
           params: { review: { action: 'request_review', comment: 'please look', component_id: component.id } },
           as: :json
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
end
