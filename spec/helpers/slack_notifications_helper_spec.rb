# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SlackNotificationsHelper, type: :helper do
  include SlackNotificationsHelper

  # Mock Setting calls globally to prevent database access during any test
  before do
    allow(Setting).to receive(:slack_enabled).and_return(true)
    allow(Setting).to receive(:slack_api_token).and_return('test-token')
  end

  describe '#send_notification' do
    let(:channel) { 'test_channel' }
    let(:message_params) do
      {
        icon: ':white_check_mark:',
        header: 'Test header',
        fields: [
          { label: 'Field 1', value: 'Value 1' },
          { label: 'Field 2', value: 'Value 2' }
        ]
      }
    end
    let(:client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(client)

      # Mock ALL Setting values that SlackNotificationsHelper might access
      allow(Setting).to receive(:slack_enabled).and_return(true)
      allow(Setting).to receive(:slack_api_token).and_return('test-token')

      # Mock cache validation methods to return success
      allow(helper).to receive(:validate_slack_api_token).and_return({ 'status' => 'success' })
      allow(helper).to receive(:validate_slack_posting_capability).and_return({
                                                                                'api_token_valid' => true,
                                                                                'posting_permissions' => true
                                                                              })
      allow(helper).to receive(:build_message).and_return([{ type: 'section', text: { type: 'mrkdwn', text: 'test' } }])
      allow(helper).to receive(:log_settings_cache_metrics)
    end

    it 'sends a message to the specified channel' do
      expect(client).to receive(:chat_postMessage).with(
        channel: channel,
        blocks: anything
      )
      expect(helper.send_notification(channel, message_params)).to be true
    end

    it 'logs an error if the channel is not found' do
      allow(client).to receive(:chat_postMessage).and_raise(
        Slack::Web::Api::Errors::ChannelNotFound.new(
          "Slack channel '#{channel}' not found"
        )
      )
      expect(Rails.logger).to receive(:error)
        .with("Slack channel '#{channel}' not found: Slack channel '#{channel}' not found")
      expect(helper.send_notification(channel, message_params)).to be false
    end

    it 'logs an error if there is a Slack API error' do
      allow(client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('Test error'))
      expect(Rails.logger).to receive(:error).with('Slack API error: Test error')
      expect(helper.send_notification(channel, message_params)).to be false
    end
  end

  describe '#get_slack_headers_icons' do
    it 'returns the correct icon and header for a given notification type' do
      expect(get_slack_headers_icons(:create_project,
                                     'create')).to eq([':white_check_mark:', 'Vulcan New Project Creation'])
      expect(get_slack_headers_icons(:update_component_membership,
                                     'update')).to eq([':loudspeaker:', 'Membership Updated on the Component'])
      expect(get_slack_headers_icons(:remove_vulcan_admin, 'remove')).to eq([':x:', 'Removing Vulcan Admin'])
      expect(get_slack_headers_icons(:update_component_membership,
                                     'update')).to eq([':loudspeaker:', 'Membership Updated on the Component'])
      expect(get_slack_headers_icons(:upload_srg,
                                     'upload')).to eq([':white_check_mark:',
                                                       'Vulcan New SRG (Security Requirement Guide) Upload'])
    end
  end
end
