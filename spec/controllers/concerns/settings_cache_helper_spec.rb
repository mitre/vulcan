# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SettingsCacheHelper, type: :helper do
  include_context 'with cache'

  let(:test_helper) do
    Class.new do
      include SettingsCacheHelper
    end.new
  end

  describe 'cache key behavior' do
    it 'generates consistent cache keys for same inputs' do
      key1 = test_helper.send(:build_settings_cache_key, 'test_cache', 'identifier123')
      key2 = test_helper.send(:build_settings_cache_key, 'test_cache', 'identifier123')

      expect(key1).to eq(key2)
    end

    it 'generates different cache keys for different inputs' do
      key1 = test_helper.send(:build_settings_cache_key, 'test_cache', 'identifier1')
      key2 = test_helper.send(:build_settings_cache_key, 'test_cache', 'identifier2')

      expect(key1).not_to eq(key2)
    end
  end

  describe '#get_cached_settings' do
    it 'returns cached data when cache hit' do
      cache_key = test_helper.send(:build_settings_cache_key, 'test', 'hit_example')
      cached_data = { 'status' => 'cached', 'data' => 'test' }
      Rails.cache.write(cache_key, cached_data)

      result = test_helper.send(:get_cached_settings, 'test', 'hit_example')

      expect(result).to eq(cached_data)
    end

    it 'executes fallback block on cache miss' do
      fallback_executed = false
      fallback_data = { 'status' => 'fresh', 'data' => 'new' }

      result = test_helper.send(:get_cached_settings, 'test', 'miss_example') do
        fallback_executed = true
        fallback_data
      end

      expect(fallback_executed).to be true
      expect(result).to eq(fallback_data)
    end

    it 'caches fresh data from fallback block' do
      fresh_data = { 'status' => 'fresh', 'timestamp' => Time.current.iso8601 }

      # First call should execute fallback and cache result
      result1 = test_helper.send(:get_cached_settings, 'test', 'cache_fresh') do
        fresh_data
      end

      # Second call should return cached result (cache hit behavior)
      result2 = test_helper.send(:get_cached_settings, 'test', 'cache_fresh') do
        raise 'Should not execute fallback on cache hit'
      end

      expect(result1['status']).to eq('fresh')
      expect(result2['status']).to eq('fresh')
    end

    it 'returns nil when no fallback block provided and cache miss' do
      result = test_helper.send(:get_cached_settings, 'test', 'no_fallback')

      expect(result).to be_nil
    end

    it 'handles cache read errors gracefully' do
      # Simulate cache read error
      allow(Rails.cache).to receive(:read).and_raise(StandardError, 'Cache unavailable')

      fallback_data = { 'status' => 'fallback' }
      result = test_helper.send(:get_cached_settings, 'test', 'error_test') do
        fallback_data
      end

      expect(result).to eq(fallback_data)
    end

    it 'logs cache metrics for monitoring' do
      expect(test_helper).to receive(:log_settings_cache_metrics).at_least(:once)

      test_helper.send(:get_cached_settings, 'test', 'metrics_test') do
        { 'data' => 'fresh' }
      end
    end
  end

  describe 'cache data storage behavior' do
    it 'stores and retrieves data correctly' do
      data = { 'test' => 'value', 'number' => 123 }

      test_helper.send(:cache_settings_data, 'test_type', 'test_id', data, expires_in: 1.hour)

      # Verify data can be retrieved
      result = test_helper.send(:get_cached_settings, 'test_type', 'test_id')
      expect(result['test']).to eq('value')
      expect(result['number']).to eq(123)
    end

    it 'handles different data types appropriately' do
      string_data = 'simple string'

      expect do
        test_helper.send(:cache_settings_data, 'test_type', 'test_id', string_data)
      end.not_to raise_error

      result = test_helper.send(:get_cached_settings, 'test_type', 'test_id')
      expect(result).to eq('simple string')
    end

    it 'handles cache errors gracefully without breaking application' do
      allow(Rails.cache).to receive(:write).and_raise(StandardError, 'Cache write failed')

      expect do
        test_helper.send(:cache_settings_data, 'test_type', 'test_id', { 'data' => 'test' })
      end.not_to raise_error
    end
  end

  describe '#with_settings_request_lock' do
    it 'executes block when no lock exists' do
      block_executed = false

      test_helper.send(:with_settings_request_lock, 'test_type', 'test_id') do
        block_executed = true
      end

      expect(block_executed).to be true
    end

    it 'skips execution when lock exists' do
      # Set a request lock
      lock_key = test_helper.send(:build_settings_cache_key, 'test_type_request_lock', 'test_id')
      Rails.cache.write(lock_key, true, expires_in: 5.seconds)

      block_executed = false
      test_helper.send(:with_settings_request_lock, 'test_type', 'test_id') do
        block_executed = true
      end

      expect(block_executed).to be false
    end

    it 'clears lock after execution' do
      lock_key = test_helper.send(:build_settings_cache_key, 'test_type_request_lock', 'test_id')

      test_helper.send(:with_settings_request_lock, 'test_type', 'test_id') do
        # Lock should exist during execution
        expect(Rails.cache.exist?(lock_key)).to be true
      end

      # Lock should be cleared after execution
      expect(Rails.cache.exist?(lock_key)).to be false
    end

    it 'clears lock even if block raises error' do
      lock_key = test_helper.send(:build_settings_cache_key, 'test_type_request_lock', 'test_id')

      expect do
        test_helper.send(:with_settings_request_lock, 'test_type', 'test_id') do
          raise StandardError, 'Test error'
        end
      end.to raise_error(StandardError, 'Test error')

      # Lock should still be cleared
      expect(Rails.cache.exist?(lock_key)).to be false
    end

    it 'handles cache errors gracefully' do
      # Simulate cache error
      allow(Rails.cache).to receive(:exist?).and_raise(StandardError, 'Cache error')

      block_executed = false
      expect do
        test_helper.send(:with_settings_request_lock, 'test_type', 'test_id') do
          block_executed = true
        end
      end.not_to raise_error

      expect(block_executed).to be true
    end
  end

  describe 'cache metrics logging behavior' do
    it 'logs cache events for monitoring' do
      expect(Rails.logger).to receive(:info).with(anything)

      test_helper.send(:log_settings_cache_metrics, 'test_event', 'test_type', 'test_id')
    end
  end
end
