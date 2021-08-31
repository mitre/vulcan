# frozen_string_literal: true

module Xccdf
  # Type for the refine-value element in a Profile; all it has
  # are three attributes, no content.  The three attributes are
  # 'idref' which refers to a Value, 'selector' which designates
  # certain element children of the Value, and 'operator' which
  # can override the operator attribute of the Value.
  # As content, the refine-value element can contain zero or more
  # remark elements, which allows the benchmark author to
  # add explanatory material or other additional prose.
  class ProfileRefineValue
    include HappyMapper

    tag 'refine-value'

    attribute :idref, String, tag: 'idref' # required
    attribute :selector, String, tag: 'selector'
    # Allowed operators for Values.  Note that most of
    # these are valid only for numeric data, but the
    # schema doesn't enforce that.    # equals
    # not equals
    # greater than
    # less than
    # greater than or equal
    # less than or equal
    # pattern match
    attribute :operator, String, tag: 'operator'

    has_many :remark, String, tag: 'remark'
  end
end
