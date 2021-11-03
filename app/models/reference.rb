# frozen_string_literal: true

# A Reference maps to the XCCDF RuleReference element type
class Reference < ApplicationRecord
  belongs_to :base_rule

  # Because from_mappings take advantage of accepts_nested_attributes, these methods
  # must return Hashes instead of an actual object to be properly created and associated
  # with the rule.
  def self.from_mapping(reference_mapping)
    attrs = reference_mapping.instance_values
    attrs.delete('href')
    attrs.delete('override')
    attrs
  end
end
