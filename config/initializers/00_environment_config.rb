# frozen_string_literal: true

# Centralized Environment Configuration
# All ports, URLs, and deployment-specific settings should be defined here
# Following Twelve-Factor App principles
#
# 12-Factor Configuration:
# - PORT and HOST are the primitives (single source of truth)
# - APP_URL and other URLs are derived automatically
# - Override VULCAN_APP_URL only if behind a proxy with different external URL

module Vulcan
  class Config
    class << self
      # Primitives - single source of truth
      def scheme
        ENV.fetch('VULCAN_SCHEME', 'http')
      end

      def host
        ENV.fetch('HOST', 'localhost')
      end

      # Ports - all configurable via ENV
      # VULCAN_RAILS_PORT is legacy alias for PORT
      def web_port
        ENV.fetch('VULCAN_RAILS_PORT', ENV.fetch('PORT', 3000)).to_i
      end

      def prometheus_port
        ENV.fetch('VULCAN_PROMETHEUS_PORT', ENV.fetch('PROMETHEUS_PORT', 9394)).to_i
      end

      def prometheus_bind
        ENV.fetch('VULCAN_PROMETHEUS_BIND', '0.0.0.0')
      end

      # URLs - derived from primitives unless explicitly overridden
      # This matches the derivation pattern in vulcan.default.yml
      def app_url
        ENV.fetch('VULCAN_APP_URL') { "#{scheme}://#{host}:#{web_port}" }
      end

      def app_host
        URI.parse(app_url).host
      end

      def app_port
        URI.parse(app_url).port
      end
    end
  end
end
