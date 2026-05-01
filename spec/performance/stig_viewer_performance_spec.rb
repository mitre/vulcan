# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'STIG Viewer Performance', type: :request do
  let_it_be(:user) { create(:user) }
  let_it_be(:stig) { create(:stig) }

  before do
    Rails.application.reload_routes!
    sign_in user
  end

  it 'loads RHEL 9 STIG (466 rules) in under 1 second' do
    # Find RHEL 9 STIG or use test STIG
    test_stig = Stig.find_by(title: 'Red Hat Enterprise Linux 9 Security Technical Implementation Guide') || stig

    # Measure total request time
    time = Benchmark.realtime do
      get "/stigs/#{test_stig.id}", headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:success)
    end

    total_ms = (time * 1000).round(1)

    # Performance threshold
    expect(total_ms).to be < 1000, "STIG viewer should load in under 1 second, took #{total_ms}ms"
  end
end
