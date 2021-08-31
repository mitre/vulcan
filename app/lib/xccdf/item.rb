# frozen_string_literal: true

module Xccdf
  # Type element type imposes constraints shared by all
  # Groups, Rules and Values.  The itemType is abstract, so
  # the element Item can never appear in a valid XCCDF document.
  # This abstract item type represents the basic data shared by all
  # Groups, Rules and Values
  class Item
    include HappyMapper

    attribute :id, String, tag: 'id' # required
    attribute :abstract, Boolean, tag: 'abstract'
    attribute :cluster_id, String, tag: 'cluster-id'
    attribute :extends, String, tag: 'extends'
    attribute :hidden, Boolean, tag: 'hidden'
    attribute :prohibit_changes, Boolean, tag: 'prohibitChanges'
    attribute :Id, String, tag: 'Id'
  end
end
