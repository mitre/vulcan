# frozen_string_literal: true

module StubConfiguration
  # Support nested hashes by converting all values into Settingslogic objects
  def to_settings(hash)
    hash.transform_values do |value|
      if value.is_a? Hash
        Settingslogic.new(value.deep_stringify_keys)
      else
        value
      end
    end
  end
end
