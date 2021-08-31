# frozen_string_literal: true

module Xccdf
  # Class ContentRef maps from the 'check-content-ref' from Benchmark XML file using HappyMapper
  class ContentRef
    include HappyMapper
    tag 'check-content-ref'
    attribute :name, String, tag: 'name'
    attribute :href, String, tag: 'href'
  end
end
