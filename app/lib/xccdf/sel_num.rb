# frozen_string_literal: true

module Xccdf
  # This type is for an element that has numeric content
  # and a selector attribute.  It is used for two of
  # the child elements of Value.
  class SelNum
    include HappyMapper

    attribute :selector, String, tag: 'selector'

    content :content, Integer
  end
end
