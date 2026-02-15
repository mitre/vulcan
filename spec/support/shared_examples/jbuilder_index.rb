# frozen_string_literal: true

##
# Shared examples for Jbuilder index JSON responses
#
# Tests that index actions return optimized JSON with:
# - Only fields needed for table display
# - Severity counts included
# - Heavy fields excluded (rules, reviews, memberships, etc.)
#
# Usage:
#   RSpec.describe 'Components', type: :request do
#     it_behaves_like 'jbuilder index', {
#       path: '/components',
#       factory: :component,
#       required_fields: %w[id name version release prefix updated_at based_on_title based_on_version],
#       excluded_fields: %w[rules reviews memberships histories]
#     }
#   end
RSpec.shared_examples 'jbuilder index' do |config|
  let(:path) { config[:path] }
  let(:factory) { config[:factory] }
  let(:required_fields) { config[:required_fields] }
  let(:excluded_fields) { config[:excluded_fields] || [] }

  it 'returns JSON with required fields for table display', :aggregate_failures do
    get path, headers: { 'Accept' => 'application/json' }

    expect(response).to have_http_status(:success)
    json = JSON.parse(response.body)

    expect(json).to be_an(Array)
    expect(json).not_to be_empty

    first_item = json.first
    required_fields.each do |field|
      expect(first_item).to have_key(field), "Missing required field: #{field}"
    end

    # All items should have severity_counts
    expect(first_item).to have_key('severity_counts')
    expect(first_item['severity_counts']).to be_a(Hash)
    expect(first_item['severity_counts']).to have_key('high')
    expect(first_item['severity_counts']).to have_key('medium')
    expect(first_item['severity_counts']).to have_key('low')
  end

  it 'does NOT include heavy/unnecessary fields', :aggregate_failures do
    get path, headers: { 'Accept' => 'application/json' }

    json = JSON.parse(response.body).first
    excluded_fields.each do |field|
      expect(json).not_to have_key(field), "Should not include heavy field: #{field}"
    end
  end
end
