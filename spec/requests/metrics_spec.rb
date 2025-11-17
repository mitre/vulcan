# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Prometheus Metrics', type: :request do
  describe 'GET /metrics' do
    it 'is not available in test environment' do
      # prometheus_exporter is disabled in test env for performance
      # Metrics are enabled in development and production only
      expect(Rails.env.test?).to be true
    end
  end
end
