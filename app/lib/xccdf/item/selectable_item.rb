# frozen_string_literal: true

module Xccdf
  # This abstract item type represents the basic data shared by all
  # Groups and Rules.
  class Item
    class SelectableItem < Item
      include HappyMapper

      attribute :selected, Boolean, tag: 'selected'
      # Data type for a Rule's weight, a non-negative real number.
      attribute :weight, Float, tag: 'weight'

      has_many :rationale, String, tag: 'rationale'
      has_many :platform, Xccdf::Idref::OverrideableIdref, tag: 'platform'
      # This idref needs to be parsed as a comma seprated list:
      # Data type for elements that have no content,
      # just a space-separated list of id references.
      has_many :requires, Idref, tag: 'requires'
      has_many :conflicts, Idref, tag: 'conflicts'
    end
  end
end
