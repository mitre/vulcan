require 'rails_helper'

RSpec.describe MessageBroadcastJob do

  let(:user1) { create(:user) }
  let(:msg) { build(:message) }

  context "Broadcast message" do
    it "passing message to channel" do
      expect {
        ActionCable.server.broadcast(
          "notifications_channel", text: 'Hello!'
        )
      }.to have_broadcasted_to("notifications_channel")
    end
    it "Perform job" do
      expect{
        MessageBroadcastJob.perform_now(msg)
      }.to have_broadcasted_to("notifications_channel")
    end
  end
end
