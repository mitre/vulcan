# frozen_string_literal: true

##
# ComponentMetadata stores additional metadata for components in a flexible JSON structure
class ComponentMetadata < ApplicationRecord
  belongs_to :component

  validates :component, uniqueness: { message: 'already has associated metadata' }
end
