# frozen_string_literal: true

module Xccdf
  # Data type for elements that have no content,
  # just a mandatory URI as an id.  (This is mainly for the
  # platform element, which uses CPE URIs and CPE Language
  # identifers used as platform identifiers.)  When referring
  # to a local CPE Language identifier, the URL should use
  # local reference syntax: "#cpeid1".
  class Platform
    include HappyMapper
    tag 'platform'

    attribute :idref, String, tag: 'idref'
  end
end
