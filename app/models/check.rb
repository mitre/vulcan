# frozen_string_literal: true

# Rule Check class
class Check < ApplicationRecord
  audited associated_with: :rule, except: %i[rule_id], max_audits: 1000
  belongs_to :rule

  # Because from_mappings take advantage of accepts_nested_attributes, these methods
  # must return Hashes instead of an actual object to be properly created and associated
  # with the rule.
  def self.from_mapping(check_mapping)
    {
      system: check_mapping.system,
      content_ref_name: check_mapping.check_content_ref.first.name,
      content_ref_href: check_mapping.check_content_ref.first.href,
      content: check_mapping.check_content.content
    }
  end
end
