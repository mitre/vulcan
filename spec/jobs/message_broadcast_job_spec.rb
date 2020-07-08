require 'rails_helper'

RSpec.describe MessageBroadcastJob, type: :job do

  context "Broadcast message" do
    it "passing message to channel" do
      expect {
      ActionCable.server.broadcast(
        "notifications_channel", text: 'Hello!'
      )
      }.to have_broadcasted_to("notifications_channel")
    end
  end
end
