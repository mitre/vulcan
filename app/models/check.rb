# frozen_string_literal: true

# Rule Check class
class Check < ApplicationRecord
  audited associated_with: :rule
  belongs_to :rule
end
