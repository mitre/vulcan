# frozen_string_literal: true

module Xccdf
  # A suggested scoring model for a Benchmark, also
  # encapsulating any parameters needed by the model.
  # Every model is designated with a URI, which
  # appears here as the system attribute.
  class Model
    include HappyMapper
    tag 'model'

    attribute :system, String, tag: 'system'

    element :param, Param, tag: 'param'
  end
end
