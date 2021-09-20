# frozen_string_literal: true

module Xccdf
  # Data type for the check-content element, which holds
  # the actual code of an enveloped check in some other
  # (non-XCCDF) language.  This element can hold almost
  # anything; XCCDF tools do not process its content directly.
  class CheckContent
    include HappyMapper

    content :content, String
  end
end
