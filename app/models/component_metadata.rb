# frozen_string_literal: true

class ComponentMetadata < ApplicationRecord
  belongs_to :component

  validates :component, uniqueness: { message: 'already has associated metadata' }
end
