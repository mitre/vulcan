# frozen_string_literal: true

module Xccdf
  # Data type for legal notice element that has text
  # content and a unique id attribute.
  class Notice
    include HappyMapper

    tag 'notice'

    attribute :id, String, tag: 'id'
    attribute :xml_lang, String, namespace: 'xml', tag: 'lang'
    attribute :xml_base, String, namespace: 'xml', tag: 'base'

    content :notice, String, tag: 'notice'
  end
end
