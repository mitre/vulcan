# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageBroadcastJob do
  let(:user1) { create(:user) }
  let(:msg) { build(:message) }

  context 'Broadcast message' do
    it 'passing message to channel' do
      expect do
        ActionCable.server.broadcast(
          'notifications_channel', text: 'Hello!'
        )
      end.to have_broadcasted_to('notifications_channel')
    end
    it 'Perform job' do
      expect do
        MessageBroadcastJob.perform_now(msg)
      end.to have_broadcasted_to('notifications_channel')
    end
    it 'fails when too many messages broadcast' do
      expect do
        expect do
          ActionCable.server.broadcast('notifications_channel', 'one')
          ActionCable.server.broadcast('notifications_channel', 'two')
        end.to have_broadcasted_to('notifications_channel').exactly(1)
      end.to raise_error('expected to broadcast exactly 1 messages to notifications_channel, but broadcast 2')
    end
  end
end
