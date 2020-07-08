require 'rails_helper'

RSpec.describe NotificationsChannel, type: :channel do

  context 'When user connects to channel' do\
    it "subscribes without streams when no room id" do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("notifications_channel")
    end

    # Test for when there are multiple rooms
    # it "rejects when room id is invalid" do
    #   subscribe(room_id: -1)

    #   expect(subscription).to be_rejected
    # end
  end
end
