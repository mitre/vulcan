# frozen_string_literal: true

module Xccdf
  # The choice element specifies a list of legal or suggested
  # choices for a Value object.  It holds one or more choice
  # elements, a mustMatch attribute, and a selector attribute.
  class SelChoices
    include HappyMapper

    attribute :must_match, Boolean, tag: 'mustMatch'
    attribute :selector, String, tag: 'selector'

    has_many :choice, String, tag: 'choice' # required
  end
end
