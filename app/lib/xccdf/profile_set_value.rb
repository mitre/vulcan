# frozen_string_literal: true

module Xccdf
  # Type for the set-value element in a Profile; it
  # has one required attribute and string content.  The
  # attribute is 'idref', it refers to a Value.
  class ProfileSetValue
    include HappyMapper

    tag 'set-value'

    attribute :idref, String, tag: 'idref' # required

    content :set_value, String
  end
end
