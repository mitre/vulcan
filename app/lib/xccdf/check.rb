# frozen_string_literal: true

module Xccdf
  # Data type for the check element, a checking system
  # specification URI, and XML content.  The content of the
  # check element is: zero or more check-export elements,
  # zero or more check-content-ref elements, and finally
  # an optional check-content element.  An content-less
  # check element isn't legal, but XSD cannot express that!
  class Check
    include HappyMapper

    tag 'check'

    attribute :system, String, tag: 'system' # required
    attribute :id, String, tag: 'id'
    attribute :selector, String, tag: 'selector'

    has_many :check_import, CheckImport, tag: 'check-import'
    has_many :check_export, CheckExport, tag: 'check-export'
    has_many :check_content_ref, CheckContentRef, tag: 'check-content-ref'
    has_one :check_content, CheckContent, tag: 'check-content'
  end
end
