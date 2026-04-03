# frozen_string_literal: true

##
# User-defined search abbreviations
# Supplements the core abbreviations defined in config/search_abbreviations.yml
#
# Core abbreviations are maintained by MITRE and updated with each release.
# User abbreviations can override core or add new org-specific terms.
#
class SearchAbbreviation < ApplicationRecord
  belongs_to :created_by, class_name: 'User', optional: true

  validates :abbreviation, presence: true, uniqueness: { case_sensitive: false }
  validates :expansion, presence: true

  scope :active, -> { where(active: true) }

  after_destroy :clear_abbreviation_cache
  # Clear cache when abbreviations change
  after_save :clear_abbreviation_cache

  private

  def clear_abbreviation_cache
    SearchAbbreviationService.clear_cache!
  end
end
