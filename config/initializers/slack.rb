# frozen_string_literal: true

# Vulcan Integration with a slack channel
# Configure Slack using Setting model with lazy loading to avoid database access during initialization
Rails.application.reloader.to_prepare do
  # Use ActiveSupport.on_load to delay Settings access until ActiveRecord is fully initialized
  ActiveSupport.on_load(:active_record) do
    if Setting.slack_enabled && Setting.slack_api_token.present?
      # Create helper instance for Slack validation caching
      slack_helper = Class.new do
        include SlackSettingsCacheHelper
      end.new

      # Validate Slack API token with caching before applying configuration
      api_token = Setting.slack_api_token
      auth_result = slack_helper.validate_slack_api_token(api_token)

      if auth_result&.dig('status') == 'success'
        Slack.configure do |config|
          config.token = api_token
        end

        Rails.logger.info 'Slack configuration applied successfully with cached validation'
      else
        Rails.logger.warn 'Slack API token validation failed, skipping Slack configuration'
        # Don't configure Slack if token validation fails
      end
    end
  end
end
