# frozen_string_literal: true

module Xccdf
  # Type for the refine-rule element in a Profile; all it has
  # are four attributes, no content.  The main attribute is
  # 'idref' which refers to a Rule, and three attributes that
  # allow the Profile author to adjust aspects of how a Rule is
  # processed during a benchmark run: weight, severity, role.
  # As content, the refine-rule element can contain zero or more
  # remark elements, which allows the benchmark author to
  # add explanatory material or other additional prose.
  class ProfileRefineRule
    include HappyMapper

    tag 'refine-rule'

    attribute :idref, String, tag: 'idref' # required
    # Data type for a Rule's weight, a non-negative real number.
    attribute :weight, Float, tag: 'weight'
    attribute :selector, String, tag: 'selector'
    # Allowed severity values for a Rule.
    # there are several possible values:
    #    unknown= severity not defined (default, for forward
    #           compatibility from XCCDF 1.0)
    #    info = rule is informational only, failing the
    #            rule does not imply failure to conform to
    #            the security guidance of the benchmark.
    #            (usually would also have a weight of 0)
    #    low = not a serious problem
    #    medium= fairly serious problem
    #    high = a grave or critical problem
    attribute :severity, String, tag: 'severity'
    # Allowed checking and scoring roles for a Rule.
    # There are several possible values:
    #    full = if the rule is selected, then check it and let the
    #           result contribute to the score and appear in reports
    #           (default, for compatibility for XCCDF 1.0).
    #    unscored = check the rule, and include the results in
    #           any report, but do not include the result in
    #           score computations (in the default scoring model
    #           the same effect can be achieved with weight=0)
    #    unchecked = don't check the rule, just force the result
    #            status to 'unknown'.  Include the rule's
    #            information in any reports.
    attribute :role, String, tag: 'role'

    has_many :remark, String, tag: 'remark'
  end
end
