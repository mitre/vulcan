# frozen_string_literal: true

module Xccdf
  # Type for a scoring model parameter: a name and a
  # string value.
  class Param
    include HappyMapper

    tag 'param'

    attribute :name, String, tag: 'name'

    content :param, String
  end
end
