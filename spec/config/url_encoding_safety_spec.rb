# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'URL parameter encoding in Vue components' do
  # REQUIREMENT: Dynamic values interpolated into URL query strings must use
  # encodeURIComponent to prevent corruption from special characters.

  let(:global_search) { Rails.root.join('app/javascript/components/navbar/GlobalSearch.vue').read }

  it 'GlobalSearch encodes rule_id in URL parameters' do
    url_lines = global_search.lines.select { |l| l.include?('rule_id=') && l.include?('href') }
    unencoded = url_lines.reject { |l| l.include?('encodeURIComponent') }
    expect(unencoded).to be_empty,
                         "URL params must use encodeURIComponent:\n#{unencoded.map(&:strip).join("\n")}"
  end
end
