require 'rails_helper'
require 'message_broadcast_job'

RSpec.describe MessageBroadcastJob, type: :job do

  let(:msg) { build(:message) }
  let(:user1) { build(:user) }

  context "Broadcast message" do
    it "passing message to channel" do
      expect {
        ActionCable.server.broadcast(
          "notifications_channel", text: 'Hello!'
        )
      }.to have_broadcasted_to("notifications_channel")
    end
    it "Perform job" do
      expect {
        ActionCable.server.broadcast(
          "notifications_channel", text: 'Hello!'
        ) {
          msg.to_json(:include => :user1)
        }
      }.to have_broadcasted_to("notifications_channel")
    end
    it "Render_message job" do
    end
  end
end
