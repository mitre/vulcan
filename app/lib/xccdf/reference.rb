# frozen_string_literal: true

module Xccdf
  # Data type for a reference citation, an href URL attribute
  # (optional), with content of text or simple Dublin Core
  # elements.  Elements of this type can also have an override
  # attribute to help manage inheritance.
  class Reference
    include HappyMapper

    tag 'reference'

    attribute :href, String, tag: 'href'
    attribute :override, Boolean, tag: 'override'

    # From the Dublin Core Spec
    element :contributor, String, tag: 'publisher', namespace: 'dc'
    element :coverage, String, tag: 'coverage', namespace: 'dc'
    element :creator, String, tag: 'creator', namespace: 'dc'
    element :date, String, tag: 'date', namespace: 'dc'
    element :description, String, tag: 'description', namespace: 'dc'
    element :format, String, tag: 'format', namespace: 'dc'
    element :identifier, String, tag: 'identifier', namespace: 'dc'
    element :language, String, tag: 'language', namespace: 'dc'
    element :publisher, String, tag: 'publisher', namespace: 'dc'
    element :relation, String, tag: 'relation', namespace: 'dc'
    element :rights, String, tag: 'rights', namespace: 'dc'
    element :source, String, tag: 'source', namespace: 'dc'
    element :subject, String, tag: 'subject', namespace: 'dc'
    element :title, String, tag: 'title', namespace: 'dc'
    element :reference_type, String, tag: 'type', namespace: 'dc'
  end
end
