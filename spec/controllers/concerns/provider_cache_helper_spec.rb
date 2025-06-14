# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProviderCacheHelper, type: :helper do
  include_context 'with cache'

  let(:test_helper) do
    Class.new do
      include ProviderCacheHelper
    end.new
  end

  describe '#generate_provider_cache_identifier' do
    it 'generates consistent identifiers for LDAP providers' do
      ldap_config = {
        'host' => 'ldap.example.com',
        'port' => 389,
        'base' => 'dc=example,dc=com',
        'method' => 'plain'
      }

      id1 = test_helper.send(:generate_provider_cache_identifier, 'ldap', ldap_config, 'corporate')
      id2 = test_helper.send(:generate_provider_cache_identifier, 'ldap', ldap_config, 'corporate')

      expect(id1).to eq(id2)
      expect(id1).to be_a(String)
      expect(id1.length).to eq(17) # First 16 chars of SHA256 hash
    end

    it 'generates different identifiers for different providers' do
      ldap_config = { 'host' => 'ldap.example.com', 'port' => 389 }
      smtp_config = { 'address' => 'smtp.example.com', 'port' => 587 }

      ldap_id = test_helper.send(:generate_provider_cache_identifier, 'ldap', ldap_config, 'default')
      smtp_id = test_helper.send(:generate_provider_cache_identifier, 'smtp', smtp_config, 'default')

      expect(ldap_id).not_to eq(smtp_id)
    end

    it 'generates different identifiers for different provider IDs' do
      config = { 'host' => 'ldap.example.com', 'port' => 389 }

      id1 = test_helper.send(:generate_provider_cache_identifier, 'ldap', config, 'corporate')
      id2 = test_helper.send(:generate_provider_cache_identifier, 'ldap', config, 'public')

      expect(id1).not_to eq(id2)
    end
  end

  describe '#test_provider_connectivity cache behavior' do
    let(:ldap_config) { { 'host' => 'ldap.example.com', 'port' => 389 } }
    let(:test_result) { { 'status' => 'success', 'provider_type' => 'ldap' } }

    it 'caches connectivity test results (cache hit/miss behavior)' do
      # Mock the actual connectivity test
      allow(test_helper).to receive(:perform_connectivity_test).and_return(test_result)

      # First call = cache miss, should call perform_connectivity_test
      result1 = test_helper.send(:test_provider_connectivity, 'ldap', ldap_config, 'corporate')
      expect(result1['status']).to eq('success')

      # Second call = cache hit, should NOT call perform_connectivity_test again
      result2 = test_helper.send(:test_provider_connectivity, 'ldap', ldap_config, 'corporate')
      expect(result2['status']).to eq('success')

      # Verify only one actual test was performed (cache working)
      expect(test_helper).to have_received(:perform_connectivity_test).once
    end

    it 'generates different cache keys for different providers' do
      ldap_result = { 'status' => 'success', 'provider_type' => 'ldap' }
      smtp_result = { 'status' => 'success', 'provider_type' => 'smtp' }

      allow(test_helper).to receive(:perform_connectivity_test).and_return(ldap_result, smtp_result)

      # Test different provider types get different cache entries
      test_helper.send(:test_provider_connectivity, 'ldap', { 'host' => 'ldap.com' }, 'test')
      test_helper.send(:test_provider_connectivity, 'smtp', { 'address' => 'smtp.com' }, 'test')

      # Should have called perform_connectivity_test twice (different cache keys)
      expect(test_helper).to have_received(:perform_connectivity_test).twice
    end
  end

  describe '#warm_provider_caches' do
    let(:ldap_providers) do
      {
        'corporate' => { 'host' => 'corp-ldap.example.com', 'port' => 389 },
        'public' => { 'host' => 'public-ldap.example.com', 'port' => 636 }
      }
    end

    it 'warms caches for multiple providers' do
      # Mock the individual cache warming methods
      allow(test_helper).to receive(:test_provider_connectivity).and_return({ status: 'success' })
      allow(test_helper).to receive(:validate_provider_config).and_return({ status: 'success' })
      allow(test_helper).to receive(:get_provider_capabilities).and_return({ capabilities: [] })

      # Create a mock thread that executes synchronously
      mock_thread = double('Thread')
      allow(mock_thread).to receive(:join)
      allow(Thread).to receive(:new) do |&block|
        # Execute the block immediately (synchronously) and return mock thread
        block.call
        mock_thread
      end

      # This should complete without errors
      expect { test_helper.send(:warm_provider_caches, 'ldap', ldap_providers) }.not_to raise_error

      # Should have called warming methods for each provider (executed synchronously)
      expect(test_helper).to have_received(:test_provider_connectivity).with('ldap', anything, 'corporate')
      expect(test_helper).to have_received(:test_provider_connectivity).with('ldap', anything, 'public')
    end

    it 'handles empty provider hash gracefully' do
      expect { test_helper.send(:warm_provider_caches, 'ldap', {}) }.not_to raise_error
    end

    it 'continues warming other providers if one fails' do
      failing_providers = {
        'good' => { 'host' => 'good-ldap.example.com', 'port' => 389 },
        'bad' => { 'host' => 'bad-ldap.example.com', 'port' => 389 }
      }

      # Mock one success and one failure
      allow(test_helper).to receive(:test_provider_connectivity) do |_type, _config, id|
        raise StandardError, 'Connection failed' if id == 'bad'

        { status: 'success' }
      end

      allow(test_helper).to receive(:validate_provider_config).and_return({ status: 'success' })
      allow(test_helper).to receive(:get_provider_capabilities).and_return({ capabilities: [] })

      # Create a mock thread that executes synchronously
      mock_thread = double('Thread')
      allow(mock_thread).to receive(:join)
      allow(Thread).to receive(:new) do |&block|
        # Execute the block immediately (synchronously) and return mock thread
        block.call
        mock_thread
      end

      expect { test_helper.send(:warm_provider_caches, 'ldap', failing_providers) }.not_to raise_error
    end
  end

  describe '#test_tcp_connectivity' do
    it 'returns success for successful connections' do
      # Mock successful TCP connection
      mock_socket = double('TCPSocket')
      allow(TCPSocket).to receive(:open).with('example.com', 80).and_return(mock_socket)
      allow(mock_socket).to receive(:close)

      result = test_helper.send(:test_tcp_connectivity, 'example.com', 80, 'test', 'provider1')

      expect(result[:status]).to eq('success')
      expect(result[:host]).to eq('example.com')
      expect(result[:port]).to eq(80)
      expect(result[:provider_type]).to eq('test')
      expect(result[:provider_id]).to eq('provider1')
    end

    it 'returns failure for connection refused' do
      # Mock connection refused
      allow(TCPSocket).to receive(:open).and_raise(Errno::ECONNREFUSED)

      result = test_helper.send(:test_tcp_connectivity, 'example.com', 80, 'test', 'provider1')

      expect(result[:status]).to eq('failed')
      expect(result[:error]).to eq('Errno::ECONNREFUSED')
    end

    it 'returns failure for timeout' do
      # Mock timeout
      allow(TCPSocket).to receive(:open).and_raise(Timeout::Error)

      result = test_helper.send(:test_tcp_connectivity, 'example.com', 80, 'test', 'provider1', timeout: 1)

      expect(result[:status]).to eq('failed')
      expect(result[:error]).to eq('Timeout::Error')
    end
  end

  describe 'provider-specific connectivity tests' do
    describe '#test_ldap_connectivity' do
      let(:ldap_config) { { 'host' => 'ldap.example.com', 'port' => 389 } }

      it 'tests LDAP connectivity and caches result' do
        # Mock successful TCP connection
        allow(test_helper).to receive(:test_tcp_connectivity).and_return({
                                                                           status: 'success',
                                                                           provider_type: 'ldap',
                                                                           provider_id: 'test',
                                                                           host: 'ldap.example.com',
                                                                           port: 389
                                                                         })

        result = test_helper.send(:test_ldap_connectivity, ldap_config, 'test')

        expect(result[:status]).to eq('success')
        expect(result[:provider_type]).to eq('ldap')

        # Check that result was cached
        cache_key = test_helper.send(:build_settings_cache_key,
                                     'ldap_connectivity',
                                     test_helper.send(:generate_provider_cache_identifier, 'ldap', ldap_config, 'test'))
        cached_result = Rails.cache.read(cache_key)
        expect(cached_result).to be_present
      end

      it 'uses default port 389 for LDAP' do
        config_without_port = { 'host' => 'ldap.example.com' }

        expect(test_helper).to receive(:test_tcp_connectivity)
          .with('ldap.example.com', 389, 'ldap', 'test')
          .and_return({ status: 'success' })

        test_helper.send(:test_ldap_connectivity, config_without_port, 'test')
      end
    end

    describe '#test_smtp_connectivity' do
      let(:smtp_config) { { 'address' => 'smtp.example.com', 'port' => 587 } }

      it 'tests SMTP connectivity and caches result' do
        allow(test_helper).to receive(:test_tcp_connectivity).and_return({
                                                                           status: 'success',
                                                                           provider_type: 'smtp',
                                                                           provider_id: 'test'
                                                                         })

        result = test_helper.send(:test_smtp_connectivity, smtp_config, 'test')

        expect(result[:status]).to eq('success')
        expect(result[:provider_type]).to eq('smtp')
      end

      it 'uses default port 587 for SMTP' do
        config_without_port = { 'address' => 'smtp.example.com' }

        expect(test_helper).to receive(:test_tcp_connectivity)
          .with('smtp.example.com', 587, 'smtp', 'test')
          .and_return({ status: 'success' })

        test_helper.send(:test_smtp_connectivity, config_without_port, 'test')
      end
    end
  end
end
