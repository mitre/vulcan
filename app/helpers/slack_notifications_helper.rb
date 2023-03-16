# frozen_string_literal: true

# This module handles items that we use across multiple controllers
# and views throughout the application
module SlackNotificationsHelper
  include SlackNotificationFields

  def client
    @client ||= Slack::Web::Client.new(token: Settings.slack.api_token)
  end

  def send_notification(channel, message_params)
    message = build_message(message_params)
    client.chat_postMessage(channel: channel, blocks: message)
  rescue Slack::Web::Api::Errors::ChannelNotFound
    flash.alert = "Slack channel '#{channel}' not found"
  rescue Slack::Web::Api::Errors::SlackError => e
    flash.alert = "Slack API error: #{e.message}"
  end

  private

  def build_message(params)
    blocks = Slack::BlockKit.blocks do |b|
      b.section do |s|
        s.text = Slack::BlockKit::Composition::Mrkdwn.new(text: "#{params[:icon]} *#{params[:header]}*")
      end

      b.divider

      params[:fields].each do |field|
        b.section do |s|
          s.text = Slack::BlockKit::Composition::Mrkdwn.new(text: "*#{field[:label]}:* #{field[:value]}")
        end
      end

      b.divider
    end
    blocks.to_json
  end
end
