require 'rails_helper'
require 'notifications_channel'

RSpec.describe NotificationsChannel, type: :channel do

  let(:user) { build(:user) }
  let(:msg) { build(:message) }
  let(:action_cable) { ActionCable.server }

  context 'When user connects to channel' do
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

  context 'Data transfer' do
    let(:message) { Message.create(body: msg['body'], user: user) }
    it 'send message out' do
      # expect(message.body).to eq(msg.body)
      # expect(action_cable.send_message(msg.body)).to change(Message, :count).by 1
    end
    it 'receive message' do

      # expect {
      #   receive(message)
      # }.to have_broadcasted_to("notifications_channel")
    end
  end
end
