# frozen_string_literal: true

module Xccdf
  # The acceptance status of an Item with an optional date attribute
  # that signifies the date of the status change.
  class Status
    include HappyMapper

    tag 'status'

    attribute :date, String, tag: 'date'

    content :status, String, tag: 'status'
  end
end
