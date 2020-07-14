require 'rails_helper'

RSpec.describe MessagesController  do

    let(:msg) { build(:message) }
    let(:user1) { build(:user) }

    before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
        # allow_any_instance_of(ApplicationController).to receive(:msg).and_return(msg)
    end

    context 'Creates message' do
        it 'adds message to database' do
            expect {
               MessagesController.create
            }.to change(msg, :user_id)
        end
    end
end
