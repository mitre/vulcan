# frozen_string_literal: true

module Xccdf
  # Type for the select element in a Profile; all it has are two
  # attributes, no content.  The two attributes are idref which
  # refers to a Group or Rule, and selected which is boolean.
  # As content, the select element can contain zero or more
  # remark elements, which allows the benchmark author to
  # add explanatory material or other additional prose.
  class ProfileSelect
    include HappyMapper
    tag 'Select'

    attribute :idref, String, tag: 'idref' # required
    attribute :selected, String, tag: 'selected' # required

    has_many :remark, String, tag: 'remark'
  end
end
