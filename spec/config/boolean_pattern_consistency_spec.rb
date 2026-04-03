# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Boolean pattern consistency' do
  it 'vulcan.default.yml does not use raw string comparison for boolean settings' do
    bad_lines = grep_config('config/vulcan.default.yml', /!= 'false'/)

    expect(bad_lines).to be_empty,
                         "Found raw string comparison for booleans (should use ActiveModel::Type::Boolean):\n" \
                         "#{bad_lines.map(&:strip).join("\n")}"
  end
end
