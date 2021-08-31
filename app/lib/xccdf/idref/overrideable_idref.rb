module Xccdf
  # Data type for elements that have no content,
  # just a mandatory URI reference, but also have
  # an override attribute for controlling inheritance.
  class Idref
    class OverrideableIdref
      include HappyMapper

      attribute :override, Boolean, tag: 'override'
    end
  end
end
