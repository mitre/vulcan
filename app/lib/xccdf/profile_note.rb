# frozen_string_literal: true

module Xccdf
  # Type for a string with embedded Value substitutions and
  # XHTML elements, an xml:lang attribute, and a profile-note tag.
  class ProfileNote
    include HappyMapper

    attribute :tag, String, tag: 'tag'

    element :sub, Idref, tag: 'sub'
  end
end
