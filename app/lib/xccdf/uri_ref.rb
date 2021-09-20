# frozen_string_literal: true

module Xccdf
  # Data type for elements that have no content, just a URI.
  class UriRef
    include HappyMapper

    attribute :uri, String, tag: 'uri' # required
  end
end
