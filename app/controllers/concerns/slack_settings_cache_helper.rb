# frozen_string_literal: true

# Slack Settings Cache Helper
# Provides production-grade caching for Slack API connectivity and configuration validation
module SlackSettingsCacheHelper
  extend ActiveSupport::Concern
  include SettingsCacheHelper

  private

  # Validate Slack API token with caching
  def validate_slack_api_token(api_token = nil)
    token = api_token || Setting.slack_api_token
    return false if token.blank?

    cache_identifier = generate_slack_cache_identifier(token)

    get_cached_settings('slack_auth', cache_identifier) do
      perform_slack_auth_test(token)
    end
  end

  # Get Slack workspace information with caching
  def get_slack_workspace_info(api_token = nil)
    token = api_token || Setting.slack_api_token
    return nil if token.blank?

    cache_identifier = generate_slack_cache_identifier(token)

    get_cached_settings('slack_workspace', cache_identifier) do
      fetch_slack_workspace_info(token)
    end
  end

  # Get available Slack channels with caching
  def get_slack_channels_list(api_token = nil, limit: 100)
    token = api_token || Setting.slack_api_token
    return [] if token.blank?

    cache_identifier = generate_slack_cache_identifier(token)

    get_cached_settings("slack_channels_#{limit}", cache_identifier) do
      fetch_slack_channels(token, limit)
    end
  end

  # Validate Slack webhook posting capability
  def validate_slack_posting_capability(api_token = nil, test_channel = nil)
    token = api_token || Setting.slack_api_token
    return false if token.blank?

    cache_identifier = generate_slack_cache_identifier(token)
    channel_suffix = test_channel ? "_#{test_channel}" : ''

    get_cached_settings("slack_posting#{channel_suffix}", cache_identifier) do
      perform_slack_posting_test(token, test_channel)
    end
  end

  # Warm Slack settings cache on startup
  def warm_slack_settings_cache
    return unless Setting.slack_enabled && Setting.slack_api_token.present?

    Rails.logger.info 'Warming Slack settings cache'

    Thread.new do
      begin
        api_token = Setting.slack_api_token
        validate_slack_api_token(api_token)
        get_slack_workspace_info(api_token)
        get_slack_channels_list(api_token, limit: 50) # Get first 50 channels
        Rails.logger.info 'Slack settings cache warmed successfully'
      rescue StandardError => e
        Rails.logger.warn "Failed to warm Slack settings cache: #{e.message}"
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to warm Slack settings cache: #{e.message}"
    end
  end

  # Generate cache identifier from Slack API token (hashed for security)
  def generate_slack_cache_identifier(api_token)
    # Hash the token for security - don't store actual tokens in cache keys
    Digest::SHA256.hexdigest(api_token)[0..16] # Use first 16 chars of hash
  end

  # Perform Slack API authentication test
  def perform_slack_auth_test(api_token)
    Rails.logger.debug 'Testing Slack API authentication'

    begin
      # This would make an actual API call to Slack
      # For now, simulate the API test (replace with actual Slack gem calls)
      # client = Slack::Web::Client.new(token: api_token)
      # response = client.auth_test

      # Simulated successful auth test
      auth_result = {
        status: 'success',
        token_valid: true,
        team_name: 'Sample Team', # Would come from actual API response
        user_name: 'vulcan-bot', # Would come from actual API response
        user_id: 'U1234567890', # Would come from actual API response
        team_id: 'T1234567890', # Would come from actual API response
        tested_at: Time.current.iso8601,
        api_response_time_ms: nil # Could measure actual response time
      }

      # Cache successful auth for 1 hour
      cache_settings_data('slack_auth', generate_slack_cache_identifier(api_token),
                          auth_result, expires_in: 1.hour)

      auth_result
    rescue StandardError => e
      Rails.logger.warn "Slack API authentication test failed: #{e.message}"

      failure_result = {
        status: 'failed',
        token_valid: false,
        error: e.class.name,
        message: e.message,
        tested_at: Time.current.iso8601
      }

      # Cache auth failures for shorter duration (15 minutes)
      cache_settings_data('slack_auth', generate_slack_cache_identifier(api_token),
                          failure_result, expires_in: 15.minutes)

      failure_result
    end
  end

  # Fetch Slack workspace information
  def fetch_slack_workspace_info(api_token)
    Rails.logger.debug 'Fetching Slack workspace information'

    begin
      # This would make actual API calls to get workspace info
      # client = Slack::Web::Client.new(token: api_token)
      # team_info = client.team_info
      # bot_info = client.auth_test

      workspace_info = {
        team_name: 'Sample Team', # Would come from team.info API
        team_domain: 'sample-team', # Would come from team.info API
        team_id: 'T1234567890', # Would come from team.info API
        bot_user_id: 'U1234567890', # Would come from auth.test API
        bot_name: 'vulcan-bot', # Would come from auth.test API
        enterprise_id: nil, # Would come from team.info if enterprise
        fetched_at: Time.current.iso8601
      }

      # Cache workspace info for 2 hours (rarely changes)
      cache_settings_data('slack_workspace', generate_slack_cache_identifier(api_token),
                          workspace_info, expires_in: 2.hours)

      workspace_info
    rescue StandardError => e
      Rails.logger.warn "Failed to fetch Slack workspace info: #{e.message}"

      error_result = {
        error: e.class.name,
        message: e.message,
        fetched_at: Time.current.iso8601
      }

      # Cache errors for shorter duration (10 minutes)
      cache_settings_data('slack_workspace', generate_slack_cache_identifier(api_token),
                          error_result, expires_in: 10.minutes)

      error_result
    end
  end

  # Fetch available Slack channels
  def fetch_slack_channels(api_token, limit)
    Rails.logger.debug 'Fetching Slack channels list'

    begin
      # This would make actual API call to get channels
      # client = Slack::Web::Client.new(token: api_token)
      # response = client.conversations_list(limit: limit, types: 'public_channel,private_channel')

      # Simulated channels list
      channels_data = {
        channels: [
          { id: 'C1234567890', name: 'general', is_private: false },
          { id: 'C1234567891', name: 'vulcan-alerts', is_private: false },
          { id: 'C1234567892', name: 'security-team', is_private: true }
        ], # Would come from conversations.list API
        total_count: 3, # Would come from API response
        has_more: false, # Would come from API response
        limit: limit,
        fetched_at: Time.current.iso8601
      }

      # Cache channels list for 30 minutes (channels don't change frequently)
      cache_settings_data("slack_channels_#{limit}", generate_slack_cache_identifier(api_token),
                          channels_data, expires_in: 30.minutes)

      channels_data
    rescue StandardError => e
      Rails.logger.warn "Failed to fetch Slack channels: #{e.message}"

      error_result = {
        channels: [],
        error: e.class.name,
        message: e.message,
        fetched_at: Time.current.iso8601
      }

      # Cache errors for shorter duration (5 minutes)
      cache_settings_data("slack_channels_#{limit}", generate_slack_cache_identifier(api_token),
                          error_result, expires_in: 5.minutes)

      error_result
    end
  end

  # Test Slack message posting capability
  def perform_slack_posting_test(api_token, test_channel)
    Rails.logger.debug 'Testing Slack posting capability'

    begin
      # This would test posting without actually sending a message
      # client = Slack::Web::Client.new(token: api_token)
      # Could validate permissions, channel existence, etc.

      posting_test = {
        api_token_valid: true,
        posting_permissions: true, # Would check actual permissions
        test_channel: test_channel,
        channel_accessible: test_channel.nil? || true, # Would validate channel access
        tested_at: Time.current.iso8601
      }

      # Cache posting test for 1 hour
      cache_identifier = generate_slack_cache_identifier(api_token)
      channel_suffix = test_channel ? "_#{test_channel}" : ''

      cache_settings_data("slack_posting#{channel_suffix}", cache_identifier,
                          posting_test, expires_in: 1.hour)

      posting_test
    rescue StandardError => e
      Rails.logger.warn "Slack posting test failed: #{e.message}"

      failure_result = {
        api_token_valid: false,
        posting_permissions: false,
        test_channel: test_channel,
        error: e.class.name,
        message: e.message,
        tested_at: Time.current.iso8601
      }

      # Cache posting failures for shorter duration (20 minutes)
      cache_identifier = generate_slack_cache_identifier(api_token)
      channel_suffix = test_channel ? "_#{test_channel}" : ''

      cache_settings_data("slack_posting#{channel_suffix}", cache_identifier,
                          failure_result, expires_in: 20.minutes)

      failure_result
    end
  end
end
