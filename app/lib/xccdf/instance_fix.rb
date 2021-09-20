# frozen_string_literal: true

module Xccdf
  # Type for an instance element in a fix element. The
  # instance element inside a fix element designates a
  # spot where the name of the instance should be
  # substituted into the fix template to generate the
  # final fix data.  The instance element in this usage
  # has one optional attribute: context.
  class InstanceFix
    include HappyMapper

    attribute :context, String, tag: 'context'
  end
end
