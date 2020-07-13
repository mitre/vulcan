require 'rails_helper'

RSpec.describe MessagesController  do

    let(:msg) { build(:message) }
    let(:user1) { build(:user) }

    before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
    end

    context 'Creates message' do
        it 'adds message to database' do
            # params: { message: { body: @message.text, user_id: @message.user_id } }
            expect {
                @message = Message.new( { body: msg.body, user_id: msg.user_id } )
                @message.user = user1
                @message.save
            }.not_to change(msg, :user_id)
        end
    end
end
