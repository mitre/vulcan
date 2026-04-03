# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'HappyMapper XXE protection' do
  # REQUIREMENT: The NONET patch must apply to ALL input types passed to
  # HappyMapper.parse — String, IO, StringIO, and Nokogiri documents.
  # Leaving any code path unprotected allows XXE/SSRF via external DTD fetching.

  include ConfigFileHelpers

  let(:initializer) { Rails.root.join('config/initializers/nokogiri_security.rb').read }

  it 'applies NONET protection to IO/StringIO inputs' do
    # IO objects must be read and parsed with NONET, not passed through unprotected
    expect(initializer).to match(/respond_to\?\(:read\).*nonet/m),
                           'IO/StringIO inputs must be read and parsed with NONET protection'
  end

  it 'applies nonet config to String and IO paths' do
    # Count occurrences of nonet — should appear in both String and IO branches
    nonet_count = initializer.scan('.nonet').length
    expect(nonet_count).to be >= 2,
                           "Expected NONET applied in both String and IO branches, found #{nonet_count} occurrence(s)"
  end
end
