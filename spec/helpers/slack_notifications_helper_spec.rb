# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SlackNotificationsHelper, type: :helper do
  include SlackNotificationsHelper

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
    end

    it 'sends a message to the specified channel' do
      expect(client).to receive(:chat_postMessage).with(
        channel: channel,
        blocks: anything
      )
      send_notification(channel, message_params)
    end

    it 'logs an error if the channel is not found' do
      allow(client).to receive(:chat_postMessage).and_raise(
        Slack::Web::Api::Errors::ChannelNotFound.new(
          "Slack channel '#{channel}' not found"
        )
      )
      expect(Rails.logger).to receive(:error)
        .with("Slack channel '#{channel}' not found: Slack channel '#{channel}' not found")
      helper.send_notification(channel, message_params)
    end

    it 'logs an error if there is a Slack API error' do
      allow(client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('Test error'))
      expect(Rails.logger).to receive(:error).with('Slack API error: Test error')
      send_notification(channel, message_params)
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
