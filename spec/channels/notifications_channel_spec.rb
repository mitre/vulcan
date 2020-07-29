# frozen_string_literal: true

require 'rails_helper'
require 'notifications_channel'

RSpec.describe NotificationsChannel, type: :channel do
  include ActiveJob::TestHelper
  include Users

  let(:user) { build(:user) }
  let(:msg) { build(:message) }
  let(:message) do
    { 'content' => 'message' }.to_json
  end

  before do
    stub_connection current_user: user
    subscribe
  end

  context 'When user connects to channel' do
    it 'subscribes without streams when no room id' do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from('notifications_channel')
    end
  end

  context 'Data transfer' do
    subject { perform :send_message, message: JSON.parse(message) }
    it 'send message out' do
      expect { subject }.to change(Message, :count).by 1
    end
  end

  context 'Broadcast to channel' do
    subject { perform :receive, message: JSON.parse(message) }
    it 'receive message' do
      expect { subject }.to have_broadcasted_to('notifications_channel')
    end
  end

  context 'updating Message Stamp' do
    subject { perform :update_time }
    it 'after read all message button' do
      subject
      expect(user.messages_stamp).to be_within(1).of(Time.zone.now)
    end
  end
end
