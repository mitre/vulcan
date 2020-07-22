# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageBroadcastJob do
  let(:user1) { create(:user) }
  let(:msg) { build(:message) }

  context 'When a message is broadcasted' do
    it 'is received on notifications_channel' do
      expect do
        ActionCable.server.broadcast(
          'notifications_channel', text: 'Hello!'
        )
      end.to have_broadcasted_to('notifications_channel')
    end
  end
  context 'When a message is created' do
    it 'it gets broadcasted to notifications_channel' do
      expect do
        MessageBroadcastJob.perform_now(msg)
      end.to have_broadcasted_to('notifications_channel')
    end
  end
end
