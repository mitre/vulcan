# frozen_string_literal: true

module Xccdf
  # This type is for an element that has string content
  # and a selector attribute.  It is used for some of
  # the child elements of Value.
  class SelString
    include HappyMapper

    attribute :selector, String, tag: 'selector'

    content :content, String
  end
end
