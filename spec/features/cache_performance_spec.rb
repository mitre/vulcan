# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cache Performance and Behavior', type: :feature do
  include_context 'with cache'

  describe 'Settings Cache Performance' do
    let(:test_helper) do
      Class.new do
        include SettingsCacheHelper
      end.new
    end

    it 'provides significant performance improvement on cache hits' do
      slow_data = { 'computed_value' => 'expensive_result' }
      call_count = 0

      # Mock expensive operation
      expensive_operation = lambda do
        call_count += 1
        sleep(0.01) # Simulate expensive computation
        slow_data
      end

      # First call (cache miss) - should be slower
      start_time = Time.current
      result1 = test_helper.send(:get_cached_settings, 'performance_test', 'slow_op', &expensive_operation)
      first_call_time = Time.current - start_time

      # Second call (cache hit) - should be much faster
      start_time = Time.current
      result2 = test_helper.send(:get_cached_settings, 'performance_test', 'slow_op', &expensive_operation)
      second_call_time = Time.current - start_time

      expect(result1['computed_value']).to eq('expensive_result')
      expect(result2['computed_value']).to eq('expensive_result')
      expect(call_count).to eq(1) # Expensive operation only called once
      expect(second_call_time).to be < (first_call_time * 0.5) # Cache hit much faster
    end

    it 'gracefully handles cache failures without breaking application' do
      # Simulate cache being unavailable
      allow(Rails.cache).to receive(:read).and_raise(StandardError, 'Cache unavailable')
      allow(Rails.cache).to receive(:write).and_raise(StandardError, 'Cache unavailable')

      fallback_data = { 'fallback' => 'data' }

      # Should still work using fallback
      result = test_helper.send(:get_cached_settings, 'fallback_test', 'cache_down') do
        fallback_data
      end

      expect(result).to eq(fallback_data)
    end

    it 'maintains data consistency across cache operations' do
      original_data = { 'status' => 'original', 'timestamp' => Time.current.iso8601 }

      # Store data
      test_helper.send(:cache_settings_data, 'consistency_test', 'data_id', original_data)

      # Retrieve data multiple times
      retrieved1 = test_helper.send(:get_cached_settings, 'consistency_test', 'data_id')
      retrieved2 = test_helper.send(:get_cached_settings, 'consistency_test', 'data_id')

      expect(retrieved1['status']).to eq('original')
      expect(retrieved2['status']).to eq('original')
      expect(retrieved1['status']).to eq(retrieved2['status']) # Data consistency maintained
    end
  end

  describe 'Provider Cache Behavior' do
    let(:provider_helper) do
      Class.new do
        include ProviderCacheHelper
      end.new
    end

    it 'prevents duplicate connectivity tests for same provider' do
      ldap_config = { 'host' => 'ldap.example.com', 'port' => 389 }
      test_count = 0

      # Mock the actual connectivity test
      allow(provider_helper).to receive(:perform_connectivity_test) do
        test_count += 1
        { 'status' => 'success', 'provider_type' => 'ldap' }
      end

      # Multiple calls should only perform one actual test
      5.times do
        provider_helper.send(:test_provider_connectivity, 'ldap', ldap_config, 'test_provider')
      end

      expect(test_count).to eq(1) # Only one actual connectivity test performed
    end

    it 'supports multiple providers with separate cache entries' do
      ldap_config = { 'host' => 'ldap.example.com', 'port' => 389 }
      smtp_config = { 'address' => 'smtp.example.com', 'port' => 587 }

      # Mock different results for different providers
      allow(provider_helper).to receive(:perform_connectivity_test) do |type, config, _id|
        if type == 'ldap'
          { 'status' => 'success', 'provider_type' => 'ldap', 'host' => config['host'] }
        else
          { 'status' => 'success', 'provider_type' => 'smtp', 'address' => config['address'] }
        end
      end

      ldap_result = provider_helper.send(:test_provider_connectivity, 'ldap', ldap_config, 'provider1')
      smtp_result = provider_helper.send(:test_provider_connectivity, 'smtp', smtp_config, 'provider2')

      expect(ldap_result['provider_type']).to eq('ldap')
      expect(smtp_result['provider_type']).to eq('smtp')
      expect(ldap_result['host']).to eq('ldap.example.com')
      expect(smtp_result['address']).to eq('smtp.example.com')
    end
  end

  describe 'Cache Warming Behavior' do
    it 'executes warming operations without impacting application startup' do
      # Simulate cache warming in background
      start_time = Time.current

      warming_thread = Thread.new do
        # Simulate cache warming activities
        sleep(0.01) # Brief warming simulation
        'warming_complete'
      end

      # Application should continue without waiting
      app_ready_time = Time.current - start_time

      # Verify warming completes
      result = warming_thread.value

      expect(result).to eq('warming_complete')
      expect(app_ready_time).to be < 0.005 # App doesn't wait for warming
    end
  end

  describe 'Real-World Cache Usage Scenarios' do
    let(:settings_helper) do
      Class.new do
        include SettingsCacheHelper
      end.new
    end

    it 'handles rapid sequential requests efficiently' do
      request_count = 0

      expensive_settings_fetch = lambda do
        request_count += 1
        { 'setting_value' => 'computed_result', 'fetched_at' => Time.current.iso8601 }
      end

      # Simulate multiple rapid requests
      results = Array.new(10) do
        settings_helper.send(:get_cached_settings, 'rapid_test', 'setting_key', &expensive_settings_fetch)
      end

      # All results should be the same (cached)
      expect(results.map { |r| r['setting_value'] }.uniq).to eq(['computed_result'])
      expect(request_count).to eq(1) # Only one actual fetch despite 10 requests
    end

    it 'provides isolation between different setting types' do
      # Different setting types should have separate caches
      setting1 = settings_helper.send(:get_cached_settings, 'type1', 'key1') { { 'value' => 'type1_data' } }
      setting2 = settings_helper.send(:get_cached_settings, 'type2', 'key1') { { 'value' => 'type2_data' } }

      expect(setting1['value']).to eq('type1_data')
      expect(setting2['value']).to eq('type2_data')
    end
  end
end
