# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
# - Project and Component metadata fields have maximum length limits
# - Prevents resource exhaustion from excessively long strings

RSpec.describe 'Input length limits' do
  describe Project do
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }
  end

  describe Component do
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:prefix).is_at_most(10) }
    it { is_expected.to validate_length_of(:title).is_at_most(500) }
    it { is_expected.to validate_length_of(:description).is_at_most(5000) }
  end
end
