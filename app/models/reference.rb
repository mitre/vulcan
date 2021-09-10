# frozen_string_literal: true

class Reference < ApplicationRecord
  belongs_to :rule

  def self.from_mapping(reference_mapping)
    attrs = reference_mapping.instance_values
    attrs.delete('href')
    attrs.delete('override')
    Reference.new(attrs)
  end
end
