# frozen_string_literal: true

module Vulcan
  # Single source of truth for the application version.
  # Read from the VERSION file at project root.
  #
  # Used by:
  #   - Rails config (config/initializers/version.rb)
  #   - Health check endpoint
  #   - Frontend (passed via layout data attributes)
  #   - release-please (bumps this file on release)
  #
  # The VERSION file contains the semver with a 'v' prefix (e.g., "v2.3.1").
  # This constant strips the prefix for clean programmatic use.
  VERSION = File.read(File.expand_path('../../VERSION', __dir__)).strip.delete_prefix('v').freeze
end
