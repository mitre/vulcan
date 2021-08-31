# frozen_string_literal: true

module Xccdf
  # Data type for the check-export element, which specifies
  # a mapping between an XCCDF internal Value id and a
  # value name to be used by the checking system or processor.
  class CheckExport
    include HappyMapper

    attribute :value_id, String, tag: 'value-id'
    attribute :export_name, String, tag: 'export-name'
  end
end
