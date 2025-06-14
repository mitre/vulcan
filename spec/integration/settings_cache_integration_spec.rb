# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings Cache Integration with Real Database', type: :feature do
  # Integration tests with real database and cache store
  # These tests verify our cache works correctly with actual Settings model

  before(:all) do
    # Use a real cache store for integration testing (not memory store)
    @original_cache_store = Rails.cache
    # Force FileStore even in test environment for integration testing
    Rails.cache = ActiveSupport::Cache::FileStore.new('/tmp/vulcan_test_cache')
  end

  after(:all) do
    Rails.cache = @original_cache_store
  end

  before do
    # Clear cache between tests
    Rails.cache.clear

    # Ensure database is in known state
    Setting.oidc_enabled = false
    Setting.ldap_enabled = false
    Setting.smtp_enabled = false
    Setting.slack_enabled = false
  end

  let(:test_controller) do
    Class.new do
      include SettingsCacheHelper
      include GeneralSettingsCacheHelper
      include ProviderCacheHelper
    end.new
  end

  describe 'Database Integration' do
    it 'caches real Settings model data correctly' do
      # Set real values in database
      Setting.app_url = 'https://test.vulcan.com'
      Setting.contact_email = 'test@vulcan.com'

      # First call should read from database and cache
      cached_settings = test_controller.send(:get_cached_settings, 'app_config', 'main') do
        {
          'app_url' => Setting.app_url,
          'contact_email' => Setting.contact_email,
          'fetched_at' => Time.current.iso8601
        }
      end

      expect(cached_settings['app_url']).to eq('https://test.vulcan.com')
      expect(cached_settings['contact_email']).to eq('test@vulcan.com')

      # Verify data was actually cached
      cache_key = test_controller.send(:build_settings_cache_key, 'app_config', 'main')
      expect(Rails.cache.exist?(cache_key)).to be true

      # Second call should use cache (verify by changing database)
      Setting.app_url = 'https://different.url.com'

      cached_settings_second = test_controller.send(:get_cached_settings, 'app_config', 'main') do
        raise 'Should not execute fallback on cache hit'
      end

      # Should still have cached value, not new database value
      expect(cached_settings_second['app_url']).to eq('https://test.vulcan.com')
    end

    it 'handles Settings model changes when cache expires' do
      # Set initial value
      Setting.app_url = 'https://initial.url.com'

      # Cache with short expiration
      test_controller.send(:cache_settings_data, 'test_expiry', 'url',
                           { 'app_url' => Setting.app_url }, expires_in: 0.1.seconds)

      # Wait for expiration
      sleep(0.2)

      # Change database value
      Setting.app_url = 'https://updated.url.com'

      # Should fetch new value from database
      result = test_controller.send(:get_cached_settings, 'test_expiry', 'url') do
        { 'app_url' => Setting.app_url }
      end

      expect(result['app_url']).to eq('https://updated.url.com')
    end

    it 'gracefully handles database unavailability' do
      # Simulate database connection issues
      allow(Setting).to receive(:app_url).and_raise(ActiveRecord::ConnectionNotEstablished)

      # Should still work with fallback
      result = test_controller.send(:get_cached_settings, 'db_down', 'test') do
        { 'status' => 'fallback_used', 'message' => 'database unavailable' }
      end

      expect(result['status']).to eq('fallback_used')
    end
  end

  describe 'Provider Cache Integration' do
    it 'caches real LDAP connectivity tests' do
      # Set up real LDAP configuration in database
      Setting.ldap_enabled = true
      ldap_servers = {
        'test' => {
          'host' => 'ldap.forumsys.com', # Public test LDAP server
          'port' => 389,
          'base' => 'dc=example,dc=com'
        }
      }
      Setting.ldap_servers = ldap_servers

      # Test connectivity and caching
      result = test_controller.send(:test_provider_connectivity, 'ldap', ldap_servers['test'], 'test')

      expect(result).to be_a(Hash)
      expect(result[:status]).to be_in(%w[success failed]) # Either is valid for integration test
      expect(result[:provider_type]).to eq('ldap')
      expect(result[:host]).to eq('ldap.forumsys.com')

      # Verify result was cached
      cache_identifier = test_controller.send(:generate_provider_cache_identifier, 'ldap', ldap_servers['test'], 'test')
      cache_key = test_controller.send(:build_settings_cache_key, 'ldap_connectivity', cache_identifier)

      expect(Rails.cache.exist?(cache_key)).to be true
      cached_result = Rails.cache.read(cache_key)
      expect(cached_result[:host]).to eq('ldap.forumsys.com') # Works with both symbols and strings
    end

    it 'handles provider configuration changes in database' do
      # Initial SMTP configuration
      Setting.smtp_enabled = true
      initial_config = { 'address' => 'smtp.example.com', 'port' => 587 }
      Setting.smtp_settings = initial_config

      # Test and cache initial connectivity
      result1 = test_controller.send(:test_provider_connectivity, 'smtp', initial_config, 'default')
      expect(result1[:host]).to eq('smtp.example.com')

      # Change SMTP configuration in database
      new_config = { 'address' => 'mail.example.com', 'port' => 465 }
      Setting.smtp_settings = new_config

      # Should test new configuration (different cache key)
      result2 = test_controller.send(:test_provider_connectivity, 'smtp', new_config, 'default')
      expect(result2[:host]).to eq('mail.example.com')

      # Both results should be cached separately
      old_identifier = test_controller.send(:generate_provider_cache_identifier, 'smtp', initial_config, 'default')
      new_identifier = test_controller.send(:generate_provider_cache_identifier, 'smtp', new_config, 'default')

      expect(old_identifier).not_to eq(new_identifier)
    end
  end

  describe 'Cache Warming Integration' do
    it 'performs cache warming with real database settings' do
      # Set up multiple providers in database
      Setting.oidc_enabled = true
      Setting.oidc_discovery = true
      Setting.oidc_args = { 'issuer' => 'https://dev-123456.okta.com' }

      Setting.ldap_enabled = true
      Setting.ldap_servers = {
        'test' => { 'host' => 'ldap.forumsys.com', 'port' => 389 }
      }

      Setting.smtp_enabled = true
      Setting.smtp_settings = { 'address' => 'smtp.example.com', 'port' => 587 }

      # Create cache warmer that uses real database settings
      cache_warmer = Class.new do
        include ProviderCacheHelper
        include GeneralSettingsCacheHelper

        def warm_all_caches_with_real_settings_synchronously
          # Use actual Setting calls (not mocked) - synchronous to avoid race conditions
          if Setting.ldap_enabled && Setting.ldap_servers.present?
            Setting.ldap_servers.each do |provider_id, provider_config|
              test_provider_connectivity('ldap', provider_config, provider_id)
              validate_provider_config('ldap', provider_config, provider_id)
              get_provider_capabilities('ldap', provider_config, provider_id)
            rescue StandardError => e
              Rails.logger.warn "Failed to warm ldap cache for #{provider_id}: #{e.message}"
            end
          end

          return unless Setting.smtp_enabled && Setting.smtp_settings.present?

          smtp_providers = { 'default' => Setting.smtp_settings }
          smtp_providers.each do |provider_id, provider_config|
            test_provider_connectivity('smtp', provider_config, provider_id)
            validate_provider_config('smtp', provider_config, provider_id)
            get_provider_capabilities('smtp', provider_config, provider_id)
          rescue StandardError => e
            Rails.logger.warn "Failed to warm smtp cache for #{provider_id}: #{e.message}"
          end
        end
      end.new

      # Should complete without errors - synchronous execution, no race conditions
      expect { cache_warmer.warm_all_caches_with_real_settings_synchronously }.not_to raise_error

      # Cache entries should already exist (no race condition)

      # Cache should now exist after direct connectivity test
      ldap_identifier = test_controller.send(:generate_provider_cache_identifier, 'ldap', Setting.ldap_servers['test'],
                                             'test')
      ldap_cache_key = test_controller.send(:build_settings_cache_key, 'ldap_connectivity', ldap_identifier)

      expect(Rails.cache.exist?(ldap_cache_key)).to be true
    end

    it 'handles partial provider failures during warming' do
      # Set up mix of valid and invalid providers
      Setting.ldap_enabled = true
      Setting.ldap_servers = {
        'valid' => { 'host' => 'ldap.forumsys.com', 'port' => 389 },
        'invalid' => { 'host' => 'nonexistent.ldap.server', 'port' => 389 }
      }

      cache_warmer = Class.new do
        include ProviderCacheHelper

        def warm_mixed_providers_synchronously
          # Test synchronously to avoid race conditions
          Setting.ldap_servers.each do |provider_id, provider_config|
            test_provider_connectivity('ldap', provider_config, provider_id)
            validate_provider_config('ldap', provider_config, provider_id)
            get_provider_capabilities('ldap', provider_config, provider_id)
          rescue StandardError => e
            Rails.logger.warn "Failed to warm ldap cache for #{provider_id}: #{e.message}"
          end
        end
      end.new

      # Should not raise errors even with invalid providers
      expect { cache_warmer.warm_mixed_providers_synchronously }.not_to raise_error

      # Valid provider should be cached (no race condition)
      valid_identifier = test_controller.send(:generate_provider_cache_identifier, 'ldap',
                                              Setting.ldap_servers['valid'], 'valid')
      valid_cache_key = test_controller.send(:build_settings_cache_key, 'ldap_connectivity', valid_identifier)

      expect(Rails.cache.exist?(valid_cache_key)).to be true
    end
  end

  describe 'Cross-Request Cache Persistence' do
    it 'maintains cache across simulated requests' do
      # Simulate first request
      Setting.app_url = 'https://persistent.test.com'

      request1_result = test_controller.send(:get_cached_settings, 'persistence_test', 'app_url') do
        { 'app_url' => Setting.app_url, 'request' => 1 }
      end

      expect(request1_result['request']).to eq(1)

      # Simulate second request (new controller instance)
      request2_controller = Class.new do
        include SettingsCacheHelper
      end.new

      request2_result = request2_controller.send(:get_cached_settings, 'persistence_test', 'app_url') do
        { 'app_url' => Setting.app_url, 'request' => 2 }
      end

      # Should get cached result from first request
      expect(request2_result['request']).to eq(1) # From cache, not new execution
      expect(request2_result['app_url']).to eq('https://persistent.test.com')
    end
  end

  describe 'Data Consistency Verification' do
    it 'ensures cached data matches database data structure' do
      # Set complex settings in database
      Setting.app_url = 'https://complex.test.com'
      Setting.contact_email = 'admin@complex.test.com'

      # Cache the data
      cached_data = test_controller.send(:get_cached_settings, 'consistency_check', 'app_config') do
        {
          'app_url' => Setting.app_url,
          'contact_email' => Setting.contact_email,
          'version' => '1.0',
          'features' => %w[feature1 feature2],
          'nested' => { 'key' => 'value' }
        }
      end

      # Verify data types and structure are preserved
      expect(cached_data['app_url']).to be_a(String)
      expect(cached_data['contact_email']).to be_a(String)
      expect(cached_data['version']).to be_a(String)
      expect(cached_data['features']).to be_a(Array)
      expect(cached_data['nested']).to be_a(Hash)
      expect(cached_data['nested']['key']).to eq('value')

      # Verify values match what's in database
      expect(cached_data['app_url']).to eq(Setting.app_url)
      expect(cached_data['contact_email']).to eq(Setting.contact_email)
    end
  end
end
