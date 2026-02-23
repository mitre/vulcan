# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Check content (check_content in exports) can be lengthy but must
# have an upper bound.
RSpec.describe Check do
  describe 'text field length validations' do
    %i[system content_ref_name content_ref_href].each do |field|
      it { is_expected.to validate_length_of(field).is_at_most(255).allow_nil }
    end

    it { is_expected.to validate_length_of(:content).is_at_most(10_000).allow_nil }
  end
end
