# frozen_string_literal: true

module Xccdf
  # Data type for the check-content-ref element, which
  # points to the code for a detached check in another file.
  # This element has no body, just a couple of attributes:
  # href and name.  The name is optional, if it does not appear
  # then this reference is to the entire other document.
  class CheckContentRef
    include HappyMapper

    attribute :href, String, tag: 'href' # required
    attribute :name, String, tag: 'name'
  end
end
