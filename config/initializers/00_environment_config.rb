# frozen_string_literal: true

# Centralized Environment Configuration
# All ports, URLs, and deployment-specific settings should be defined here
# Following Twelve-Factor App principles

module Vulcan
  class Config
    class << self
      # Ports - all configurable via ENV with VULCAN_ prefix
      def web_port
        ENV.fetch('VULCAN_RAILS_PORT', ENV.fetch('PORT', 3000)).to_i
      end

      def prometheus_port
        ENV.fetch('VULCAN_PROMETHEUS_PORT', 9394).to_i
      end

      def prometheus_bind
        ENV.fetch('VULCAN_PROMETHEUS_BIND', '0.0.0.0')
      end

      # URLs
      def app_url
        ENV.fetch('VULCAN_APP_URL', "http://localhost:#{web_port}")
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
