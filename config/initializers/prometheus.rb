# frozen_string_literal: true

# Prometheus metrics exporter configuration
# See: https://github.com/discourse/prometheus_exporter
#
# Single-process mode: Runs metrics server in a background thread
# Metrics available at http://localhost:9394/metrics

unless Rails.env.test?
  require 'prometheus_exporter/server'
  require 'prometheus_exporter/middleware'
  require 'prometheus_exporter/instrumentation'

  # Only start prometheus server when running as a server (not during rake tasks, console, etc.)
  # Check if we're running via rails server or puma
  if defined?(Rails::Server) || File.basename($0) == 'puma'
    # Start metrics server in background thread (single-process mode)
    # This is simpler than running separate prometheus_exporter process
    server = PrometheusExporter::Server::WebServer.new bind: '0.0.0.0', port: 9394
    Thread.new { server.start }

    # Wire up a local client that sends to the in-process server
    PrometheusExporter::Client.default = PrometheusExporter::LocalClient.new(collector: server.collector)
  end

  # Middleware to track HTTP request metrics (requests/sec, duration, etc.)
  Rails.application.middleware.unshift PrometheusExporter::Middleware

  # Instrument Active Record queries (connection pool, query time)
  PrometheusExporter::Instrumentation::ActiveRecord.start(
    custom_labels: { app: 'vulcan' },
    config_labels: [:database, :host]
  )

  # Instrument Process metrics (memory, GC, heap, RSS)
  PrometheusExporter::Instrumentation::Process.start(type: 'web')
end
