# frozen_string_literal: true

require_relative '../../lib/vulcan/version'

# Expose Vulcan::VERSION via Rails config for controllers, views, and middleware.
Rails.application.config.vulcan_version = Vulcan::VERSION
