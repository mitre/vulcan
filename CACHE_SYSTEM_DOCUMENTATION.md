# Vulcan Cache System Documentation

## Overview

Vulcan implements a comprehensive, production-grade caching system designed for high performance, reliability, and maintainability. The system provides universal caching for all settings and provider connectivity tests, with built-in error handling, metrics, and multi-provider support.

## Architecture

### Core Components

1. **`CacheConfiguration`** - Centralized constants and configuration
2. **`SettingsCacheHelper`** - Universal settings caching foundation
3. **`ProviderCacheHelper`** - Multi-provider connectivity caching
4. **`GeneralSettingsCacheHelper`** - Application settings caching
5. **Provider-specific helpers** - LDAP, OIDC, SMTP, Slack extensions

### Design Principles

- **DRY (Don't Repeat Yourself)** - Common functionality extracted to base helpers
- **HashWithIndifferentAccess** - Consistent symbol/string key access throughout
- **Configurable Durations** - No magic numbers, all timeouts/durations centralized
- **Graceful Degradation** - Cache failures don't break application functionality
- **Production-Ready** - Comprehensive error handling, logging, and monitoring

## Cache Configuration

### Duration Constants (`CacheConfiguration::CACHE_DURATIONS`)

```ruby
# Connectivity tests - network can be variable
connectivity_success: 15.minutes     # Successful connections cached longer
connectivity_failure: 5.minutes      # Failed connections expire quickly

# Authentication results - more stable than connectivity
authentication_success: 1.hour       # Valid auth tokens cached longer
authentication_failure: 15.minutes   # Failed auth expires quickly

# Provider capabilities - very stable
capabilities: 2.hours                 # Rarely change

# Configuration validation - stable
config_validation: 1.hour            # Settings don't change often

# General application settings - moderately stable
general_settings: 30.minutes         # Balance freshness vs performance

# OIDC discovery documents - stable endpoints
oidc_discovery: 1.hour               # Discovery docs rarely change

# Provider-specific overrides
smtp_connectivity_success: 30.minutes # Mail servers more stable than LDAP
slack_api_success: 1.hour            # API tokens very stable
```

### Timeout Constants (`CacheConfiguration::TIMEOUTS`)

```ruby
ldap_connection: 5.seconds    # LDAP typically fast
smtp_connection: 10.seconds   # SMTP can be slower
slack_api: 15.seconds         # API calls can take time
oidc_discovery: 10.seconds    # Discovery endpoints usually fast
default_tcp: 10.seconds       # Fallback for unknown providers
```

### Helper Methods

```ruby
# Get appropriate cache duration
cache_duration_for('ldap', 'connectivity', success: true)
# => 15.minutes

# Get connection timeout
timeout_for('smtp')
# => 10.seconds

# Get request lock timeout
request_lock_timeout_for('authentication')
# => 10.seconds
```

## Core Caching Helpers

### SettingsCacheHelper

Universal foundation for all settings caching in Vulcan.

#### Key Features:
- **Namespaced cache keys** - `app:env:version:type:identifier`
- **Automatic metadata** - Adds timestamps, versions, expiration info
- **Request locking** - Prevents concurrent identical requests
- **Error handling** - Graceful degradation when cache unavailable
- **Metrics logging** - Structured JSON logs for monitoring

#### Usage Examples:

```ruby
# Cache with fallback
cached_data = get_cached_settings('app_config', 'main') do
  {
    'app_url' => Setting.app_url,
    'contact_email' => Setting.contact_email
  }
end

# Direct cache write
cache_settings_data('user_prefs', user.id, preferences, expires_in: 1.hour)

# With request locking to prevent thundering herd
with_settings_request_lock('oidc_discovery', issuer_id) do
  fetch_oidc_discovery_document(issuer)
end
```

### ProviderCacheHelper

DRY base for all provider-specific caching (LDAP, OIDC, SMTP, Slack).

#### Key Features:
- **Multi-provider support** - Handle multiple instances of same provider type
- **Universal cache identifiers** - Consistent across all provider types
- **TCP connectivity testing** - Common network testing with configurable timeouts
- **Provider normalization** - HashWithIndifferentAccess for all configurations
- **Background cache warming** - Thread-based warming without blocking startup

#### Usage Examples:

```ruby
# Test provider connectivity (cached automatically)
result = test_provider_connectivity('ldap', ldap_config, 'corporate')

# Warm multiple provider caches in background
warm_provider_caches('ldap', {
  'corporate' => ldap_corporate_config,
  'partner' => ldap_partner_config
})

# Generate consistent cache identifier
identifier = generate_provider_cache_identifier('smtp', smtp_config, 'mail1')
```

## Provider-Specific Implementation

### LDAP Caching

```ruby
# Test LDAP connectivity with caching
def test_ldap_connectivity(server_config, server_name)
  config = normalize_provider_config(server_config)
  host = config[:host]
  port = config[:port] || 389

  result = test_tcp_connectivity(host, port, 'ldap', server_name)

  # Cache with LDAP-specific durations
  cache_identifier = generate_provider_cache_identifier('ldap', server_config, server_name)
  expires_in = cache_duration_for('ldap', 'connectivity', success: result[:status] == 'success')
  cache_settings_data('ldap_connectivity', cache_identifier, result, expires_in: expires_in)

  result
end
```

### SMTP Caching

```ruby
# Test SMTP connectivity with caching
def test_smtp_connectivity(smtp_config, provider_id)
  config = normalize_provider_config(smtp_config)
  host = config[:address]
  port = config[:port] || 587

  result = test_tcp_connectivity(host, port, 'smtp', provider_id)

  # SMTP servers are more stable - longer cache duration
  expires_in = cache_duration_for('smtp', 'connectivity', success: result[:status] == 'success')
  cache_settings_data('smtp_connectivity', cache_identifier, result, expires_in: expires_in)

  result
end
```

## Cache Warming System

### Startup Cache Warming

The cache warming system pre-populates caches during application startup for optimal performance.

```ruby
# config/initializers/settings_cache_warming.rb
Rails.application.reloader.to_prepare do
  next if Rails.env.test?

  # Check database readiness
  next unless ActiveRecord::Base.connection.table_exists?('settings')

  cache_warmer.warm_all_settings_caches
end
```

### Multi-Provider Warming

```ruby
def warm_all_settings_caches
  Rails.logger.info "Starting multi-provider settings cache warming"

  # General settings (always warmed)
  warm_general_settings_cache

  # Provider-specific warming (conditional)
  warm_oidc_providers if Setting.oidc_enabled
  warm_ldap_providers if Setting.ldap_enabled && Setting.ldap_servers.present?
  warm_smtp_providers if Setting.smtp_enabled && Setting.smtp_settings.present?
  warm_slack_providers if Setting.slack_enabled && Setting.slack_api_token.present?

  Rails.logger.info "Multi-provider settings cache warming completed"
end
```

### Background Threading

Cache warming uses background threads to avoid blocking application startup:

```ruby
def warm_provider_caches(provider_type, providers_hash)
  Thread.new do
    providers_hash.each do |provider_id, provider_config|
      begin
        test_provider_connectivity(provider_type, provider_config, provider_id)
        validate_provider_config(provider_type, provider_config, provider_id)
        get_provider_capabilities(provider_type, provider_config, provider_id)
      rescue StandardError => e
        Rails.logger.warn "Failed to warm #{provider_type} cache for #{provider_id}: #{e.message}"
      end
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to warm #{provider_type} provider caches: #{e.message}"
  end
end
```

## Error Handling & Monitoring

### Graceful Degradation

All cache operations include comprehensive error handling:

```ruby
begin
  cached = Rails.cache.read(cache_key)
  return cached if cached
rescue StandardError => e
  Rails.logger.warn "Failed to read settings cache: #{e.message}"
  # Continue to fallback - application keeps working
end

# Execute fallback if cache unavailable
return yield if block_given?
```

### Metrics Logging

Structured JSON logging for monitoring cache performance:

```ruby
def log_settings_cache_metrics(event, cache_type, identifier, metadata = {})
  metrics = {
    event: "settings_cache_#{event}",
    cache_type: cache_type,
    identifier: identifier,
    cache_version: CacheConfiguration::CACHE_VERSION,
    timestamp: Time.current.iso8601
  }.merge(metadata)

  Rails.logger.info "[SETTINGS_CACHE_METRICS] #{metrics.to_json}"
end
```

## Cache Key Strategy

### Namespacing Format

```
app_name:environment:version:cache_type:identifier
```

Example:
```
vulcan_vue:production:1.1:ldap_connectivity:a1b2c3d4e5f6g7h8
```

### Cache Key Components

- **`app_name`** - Rails application name (multi-tenant ready)
- **`environment`** - Rails environment (development, test, production)
- **`version`** - Cache version for invalidation during upgrades
- **`cache_type`** - Type of cached data (ldap_connectivity, oidc_discovery, etc.)
- **`identifier`** - Unique identifier for specific cache entry

### Provider Cache Identifiers

Generated using SHA256 hash of connection parameters:

```ruby
# LDAP identifier based on host, port, base, method
cache_key_base = "ldap:corporate:ldap.example.com:389:dc=example,dc=com:plain"
identifier = Digest::SHA256.hexdigest(cache_key_base)[0..16]
```

## Testing Strategy

### Test Levels

1. **Unit Tests** - Individual helper methods with mocked dependencies
2. **Integration Tests** - Real database, cache store, and network connections
3. **Behavioral Tests** - User-facing cache behavior and performance
4. **Load Tests** - Concurrent access and cache warming

### Test Configuration

```ruby
# Use HashWithIndifferentAccess in tests for consistency
RSpec.shared_context 'with cache', :with_cache do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end
end
```

### Integration Testing

Tests verify cache works correctly with real database and providers:

```ruby
# Integration test verifying real database interaction
it 'caches real Settings model data correctly' do
  Setting.app_url = 'https://test.vulcan.com'

  cached_settings = test_controller.get_cached_settings('app_config', 'main') do
    { 'app_url' => Setting.app_url }
  end

  expect(cached_settings['app_url']).to eq('https://test.vulcan.com')
  expect(Rails.cache.exist?(cache_key)).to be true
end
```

## Performance Characteristics

### Cache Performance Benefits

- **Cache Hits**: ~1000x faster than database/network calls
- **Startup Time**: Cache warming reduces initial request latency
- **Network Reduction**: Connectivity tests cached for 15+ minutes
- **Database Load**: Settings queries cached for 30+ minutes

### Memory Usage

- **Cache Size**: Automatically managed by Rails.cache
- **Cleanup**: Built-in expiration prevents unbounded growth
- **Efficiency**: Only active providers cached, unused providers ignored

### Monitoring Metrics

Key metrics for production monitoring:

- **Cache Hit Rate** - Percentage of requests served from cache
- **Cache Miss Latency** - Time to populate cache on miss
- **Provider Availability** - Success rate of connectivity tests
- **Cache Warming Time** - Duration of startup cache population

## Migration & Upgrades

### Cache Version Management

When making breaking changes to cached data structure:

1. Increment `CacheConfiguration::CACHE_VERSION`
2. Deploy new version
3. Old cache entries automatically expire
4. New cache entries use updated structure

### Backward Compatibility

- HashWithIndifferentAccess ensures symbol/string compatibility
- Graceful degradation handles cache format changes
- Fallback mechanisms work regardless of cache state

## Best Practices

### Development Guidelines

1. **Always use configured durations** - Never hardcode cache timeouts
2. **Include error handling** - Wrap cache operations in try/catch
3. **Log cache events** - Use structured logging for monitoring
4. **Test with real data** - Include integration tests with actual database
5. **Use indifferent access** - Ensure compatibility with symbols and strings

### Production Deployment

1. **Monitor cache hit rates** - Low hit rates indicate configuration issues
2. **Watch cache warming logs** - Ensure providers are warming successfully
3. **Set up alerting** - Alert on cache warming failures or high miss rates
4. **Plan cache size** - Monitor memory usage in production
5. **Test failover scenarios** - Ensure graceful degradation works

### Performance Optimization

1. **Tune cache durations** - Balance freshness vs performance
2. **Optimize cache keys** - Shorter keys reduce memory overhead
3. **Batch cache operations** - Warm related caches together
4. **Monitor network timeouts** - Adjust based on provider performance
5. **Use background warming** - Avoid blocking user requests

## Troubleshooting

### Common Issues

1. **Cache not persisting** - Check Rails.cache configuration
2. **Symbol/string key errors** - Ensure HashWithIndifferentAccess usage
3. **Timeouts during startup** - Database not ready during cache warming
4. **Memory growth** - Check cache expiration configuration
5. **Low hit rates** - Verify cache key generation consistency

### Debug Tools

```ruby
# Check cache contents
Rails.cache.read(cache_key)

# Verify cache existence
Rails.cache.exist?(cache_key)

# Clear specific cache
Rails.cache.delete(cache_key)

# Clear all caches
Rails.cache.clear
```

### Log Analysis

Cache metrics logs provide debugging information:

```json
{
  "event": "settings_cache_hit",
  "cache_type": "ldap_connectivity",
  "identifier": "a1b2c3d4e5f6g7h8",
  "cache_version": "1.1",
  "timestamp": "2025-06-13T16:58:29Z"
}
```

## Future Enhancements

### Planned Features

1. **Cache Statistics Dashboard** - Web UI for cache performance monitoring
2. **Distributed Caching** - Redis/Memcached support for multi-server deployments
3. **Intelligent Warming** - Predictive cache warming based on usage patterns
4. **Cache Compression** - Reduce memory usage for large cached objects
5. **A/B Testing** - Compare cache strategies for optimization

### Architecture Evolution

The cache system is designed for future expansion:

- **Provider plugins** - Easy addition of new provider types
- **Cache stores** - Support for additional backend stores
- **Monitoring integration** - Native integration with APM tools
- **Multi-tenancy** - Enhanced support for tenant-isolated caching
- **Global cache** - Cross-environment cache sharing for stable data

This cache system provides a solid foundation for high-performance, reliable settings and provider management in Vulcan, with comprehensive testing and production-ready error handling.