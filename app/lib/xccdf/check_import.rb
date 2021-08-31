# frozen_string_literal: true

module Xccdf
  # Data type for the check-import element, which specifies a
  # value that the benchmark author wishes to retrieve from the
  # the checking system.  The import-name attribute gives the
  # name or id of the value in the checking system. When the
  # check-import element appears in the context of a rule-result,
  # then the element's content is the desired value.  When the
  # check-import element appears in the context of a Rule, then
  # it should be empty and any content must be ignored.
  class CheckImport
    include HappyMapper

    attribute :import_name, String, tag: 'import-name'

    content :content, String
  end
end
