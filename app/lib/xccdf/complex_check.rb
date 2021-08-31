# frozen_string_literal: true

module Xccdf
  # The type for an element that can contains a boolean
  # expression based on checks.  This element can have only
  # complex-check and check elements as children.  It has two
  # attributes: operator and negate.  The operator attribute
  # can have values "OR" or "AND", and the negate attribute is
  # boolean.  See the specification document for truth tables
  # for the operators and negations.  Note: complex-check is
  # defined in this way for conceptual equivalence with OVAL.
  class ComplexCheck
    include HappyMapper

    tag 'complex-check'

    # The type for the allowed operator names for the
    # complex-check operator attribute.  For now, we just
    # allow boolean AND and OR as operators.  (The
    # complex-check has a separate mechanism for negation.)
    attribute :operator, String, tag: 'operator'
    attribute :negate, Boolean, tag: 'negate'

    # Either is required, cannot mix types
    has_many :check, Check, tag: 'check'
    has_many :complex_check, ComplexCheck, tag: 'complex-check'
  end
end
