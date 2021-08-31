# frozen_string_literal: true

module Xccdf
  # The benchmark tag is the top level element representing a
  # complete security checklist, including descriptive text,
  # metadata, test items, and test results.  A Benchmark may
  # be signed with a XML-Signature.
  class Benchmark
    include HappyMapper

    tag 'Benchmark'

    register_namespace 'dsig', 'http://www.w3.org/2000/09/xmldsig#'
    register_namespace 'xsi', 'http://www.w3.org/2001/XMLSchema-instance'
    register_namespace 'cpe', 'http://cpe.mitre.org/language/2.0'
    register_namespace 'xhtml', 'http://www.w3.org/1999/xhtml'
    register_namespace 'dc', 'http://purl.org/dc/elements/1.1/'

    attribute :id, String, tag: 'id' # required
    attribute :Id, String, tag: 'Id'
    attribute :resolved, Boolean, tag: 'resolved'
    attribute :style, String, tag: 'style'
    attribute :stylehref, String, tag: 'style-href'

    has_many :status, Status, tag: 'status' # required
    has_many :title, String, tag: 'title'
    has_many :description, String, tag: 'description'
    has_many :notice, Notice, tag: 'notice'
    # Arbitrary XHTML
    has_many :front_matter, String, tag: 'front-matter'
    # Arbitrary XHTML
    has_many :rear_matter, String, tag: 'rear-matter'
    has_many :reference, Reference, tag: 'reference'
    has_many :plaintext, Plaintext, tag: 'plain-text'
    # <Not implemented>
    # One of:
    # cisp:platform-definitions (XCCDF 1.0)
    # cdfp:Platform-Specification (XCCDF 1.1)
    # cpe1:cpe-list (XCCDF 1.1.3)
    # cpe2:platform-specification (SCAP 1.0 / XCCDF 1.1.4)
    # </Not implemented>
    has_many :platform, Platform, tag: 'platform'
    has_one :version, Version, tag: 'version' # required
    # element :metadata, Metadata, tag: 'metadata'
    has_many :model, Model, tag: 'model'
    has_many :profile, Profile, tag: 'Profile'
    has_many :value, Xccdf::Item::Value, tag: 'Value'
    has_many :group, Xccdf::Item::SelectableItem::Group, tag: 'Group'
    has_many :rule, Xccdf::Item::SelectableItem::Rule, tag: 'Rule'
    # <Not implemented>
    # Vulcan is not concerned with TestResults
    # has_many :testresult, TestResult, tag: 'TestResult'
    # </Not implemented>
    # element :signature, String, tag: 'signature'
  end
end
