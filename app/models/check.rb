# frozen_string_literal: true

# Rule Check class
class Check < ApplicationRecord
  audited associated_with: :rule, except: %i[rule_id], max_audits: 1000
  belongs_to :rule

  def self.from_mapping(check_mapping)
    Check.new(
      system: check_mapping.system,
      content_ref_name: check_mapping.check_content_ref.first.name,
      content_ref_href: check_mapping.check_content_ref.first.href,
      content: check_mapping.check_content
    )
  end
end
