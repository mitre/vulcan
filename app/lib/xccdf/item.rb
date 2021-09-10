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

    has_many :status, Status, tag: 'status'
    has_many :version, Version, tag: 'version'
    has_many :title, String, tag: 'title'
    # XHTML
    has_many :description, String, tag: 'description'
    has_many :warning, Warning, tag: 'warning'
    has_many :question, String, tag: 'question'
    has_many :reference, Reference, tag: 'reference'
  end
end
