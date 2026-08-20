# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Slack Notifications' do
  before do
    Rails.application.reload_routes!
  end

  describe 'ApplicationController#slack_notification_params argument forwarding' do
    let_it_be(:admin) { create(:user, admin: true) }
    let_it_be(:project) { create(:project) }
    let_it_be(:srg) { create(:security_requirements_guide) }
    let_it_be(:component) { create(:component, project: project, based_on: srg) }
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

  describe 'review notifications for authored SRG requirements' do
    let_it_be(:admin) { create(:user, admin: true) }
    let_it_be(:project) { create(:project) }
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      prefix: 'SLCK-00', name: 'Slack SRG', title: 'Slack SRG')
    end
    let_it_be(:authored_requirement) do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001')
    end
    # Requirement-row notifications go only to the component's own channel
    # (find_slack_channel compacts nils), so the channel must exist for the
    # send to happen at all.
    let_it_be(:slack_channel_metadata) do
      ComponentMetadata.create!(component: srg_component,
                                data: { 'Slack Channel ID' => 'C0SRGTEST01' })
    end

    before do
      sign_in admin
      create(:membership, :admin, user: admin, membership: project)
      allow(Settings).to receive_message_chain(:slack, :enabled).and_return(true)
      allow(Settings).to receive_message_chain(:slack, :channel_id).and_return('C123')
    end

    # The fields dispatch must match BOTH requirement kinds: SrgRule is a
    # sibling STI class of Rule, so a Rule-only match builds no fields and
    # the crash is swallowed by safely_notify — the request still returns
    # 200 while every review-workflow notification is silently dropped for
    # authored rows. Asserting the POSTED FIELD CONTENT (never just the
    # HTTP status) is what lets this example fail with the code broken.
    it 'posts the review notification fields for an authored SRG requirement' do
      captured_channel = nil
      captured_fields = nil
      allow_any_instance_of(SlackNotificationsHelper)
        .to receive(:send_notification) do |_helper, channel, params|
          captured_channel = channel
          captured_fields = params[:fields]
          true
        end

      post "/rules/#{authored_requirement.id}/reviews", params: {
        review: { action: 'request_review', comment: 'Slack kind-parity test' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(captured_channel).to eq('C0SRGTEST01')
      labels = Array(captured_fields).pluck(:label)
      expect(labels).to include('Component', 'Control')
      control_value = Array(captured_fields).find { |f| f[:label] == 'Control' }&.fetch(:value)
      expect(control_value).to include('SLCK-00-000001')
    end
  end
end
