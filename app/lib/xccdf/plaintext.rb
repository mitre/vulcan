# frozen_string_literal: true

module Xccdf
  # Data type for a reusable text block, with an
  # unique id attribute.
  class Plaintext
    include HappyMapper

    tag 'plain-text'

    attribute :id, String, tag: 'id'

    content :plaintext, String
  end
end
