# frozen_string_literal: true

# Load our Settings compatibility layer which provides nested API
# over the flat rails-settings-cached Setting model
require_relative '../settings'

# rails-settings-cached configuration
# The Setting model is automatically loaded by Rails
# Default values are defined in the model using environment variables
# Database overrides are handled automatically by the gem
# Settings class provides backward-compatible nested API
