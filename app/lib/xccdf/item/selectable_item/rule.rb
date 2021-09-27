# frozen_string_literal: true

module Xccdf
  # Data type for the Rule element that represents a
  # specific benchmark test.
  class Item
    class SelectableItem
      class Rule < SelectableItem
        include HappyMapper

        tag 'Rule'
        # Allowed checking and scoring roles for a Rule.
        # There are several possible values:
        #    full = if the rule is selected, then check it and let the
        #           result contribute to the score and appear in reports
        #           (default, for compatibility for XCCDF 1.0).
        #    unscored = check the rule, and include the results in
        #           any report, but do notsev include the result in
        #           score computations (in the default scoring model
        #           the same effect can be achieved with weight=0)
        #    unchecked = don't check the rule, just force the result
        #            status to 'unknown'.  Include the rule's
        #            information in any reports.
        attribute :role, String, tag: 'role'
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
        attribute :multiple, Boolean, tag: 'multiple'

        has_many :ident, Ident, tag: 'ident'
        has_one :impact_metric, String, tag: 'impact-metric'
        has_many :profile_note, ProfileNote, tag: 'profile-note'
        has_many :fixtext, FixText, tag: 'fixtext'
        has_many :fix, Fix, tag: 'fix'
        has_many :check, Check, tag: 'check'
        has_many :complex_check, ComplexCheck, tag: 'complex-check'
      end
    end
  end
end
