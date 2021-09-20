# frozen_string_literal: true

module Xccdf
  # Data type for the Profile element, which holds a
  # specific tailoring of the Benchmark.  The main part
  # of a Profile is the selectors: select, set-value,
  # refine-rule, and refine-value.  A Profile may also be
  # signed with an XML-Signature.
  class Profile
    include HappyMapper
    tag 'Profile'
    attribute :id, String, tag: 'id' # required
    attribute :prohibit_changes, Boolean, tag: 'prohibitChanges'
    attribute :abstract, Boolean, tag: 'abstract'
    attribute :note_tag, String, tag: 'note-tag'
    attribute :extends, String, tag: 'extends'
    attribute :Id, String, tag: 'id'

    has_many :status, Status, tag: 'status'
    has_many :version, Version, tag: 'version'
    has_many :title, String, tag: 'title' # required
    has_many :description, String, tag: 'description'
    has_many :platform, Platform, tag: 'platform'
    has_many :select, ProfileSelect, tag: 'select'
    has_many :set_value, ProfileSetValue, tag: 'set-value'
    has_many :refine_value, ProfileRefineValue, tag: 'refine-value'
    has_many :refine_rule, ProfileRefineRule, tag: 'refine-rule'
  end
end
