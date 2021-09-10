# frozen_string_literal: true

module Xccdf
  # Data type for the Value element, which represents a
  # tailorable string, boolean, or number in the Benchmark.
  class Item
    class Value < Item
      include HappyMapper

      tag 'Value'

      # Allowed data types for Values, just string, numeric,
      # and true/false.
      attribute :type, String, tag: 'type'
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
      attribute :interactive, Boolean, tag: 'interactive'
      # Allowed interface hint values.  When an interfaceHint
      # appears on the Value, it provides a suggestion to a
      # tailoring or benchmarking tool about how to present the
      # UI for adjusting a Value.
      # choice
      # textilne
      # text
      # date
      # datetime
      attribute :interface_hint, String, tag: 'interfaceHint'

      has_many :value, SelString, tag: 'value' # required
      has_many :default, SelString, tag: 'default'
      has_many :match, SelString, tag: 'match'
      has_many :lower_bound, SelNum, tag: 'lower-bound'
      has_many :upper_bound, SelNum, tag: 'upper-bound'
      has_many :choices, SelChoices, tag: 'choices'
      has_many :source, UriRef, tag: 'source'
      # has_one :signature, String, tag: 'signature'
    end
  end
end
