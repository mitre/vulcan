# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Slack Notifications', type: :request do
  before do
    Rails.application.reload_routes!
  end

  describe 'ApplicationController#slack_notification_params argument forwarding' do
    let(:admin) { create(:user, admin: true) }
    let(:project) { create(:project) }
    let(:srg) { create(:security_requirements_guide) }
    let(:component) { create(:component, project: project, based_on: srg) }
    let(:rule) { component.rules.first }

    before do
      sign_in admin
      create(:membership, :admin, user: admin, membership: project)
      # Enable Slack but stub actual API calls
      allow(Settings).to receive_message_chain(:slack, :enabled).and_return(true)
      allow(Settings).to receive_message_chain(:slack, :channel_id).and_return('C123')
      allow_any_instance_of(SlackNotificationsHelper).to receive(:send_notification).and_return(true)
    end

    it 'forwards comment argument when creating a review with slack notification' do
      # Bug fix: def slack_notification_params(*) couldn't forward unnamed rest args
      # Fixed to: def slack_notification_params(*args) and forward *args
      #
      # This test triggers the full call chain:
      # send_slack_notification(:request_review, rule, comment)
      # -> slack_notification_params(:request_review, rule, *args)
      # -> get_slack_notification_fields(..., *args)

      post "/rules/#{rule.id}/reviews", params: {
        review: {
          action: 'request_review',
          comment: 'This comment should be forwarded through all method calls'
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
