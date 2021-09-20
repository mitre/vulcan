# frozen_string_literal: true

module Xccdf
  # Data type for elements that have no content,
  # just a mandatory id reference.
  class Idref
    include HappyMapper

    attribute :idref, String, tag: 'idref' # required
  end
end
