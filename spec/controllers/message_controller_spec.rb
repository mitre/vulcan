require 'rails_helper'

RSpec.describe MessagesController  do

    let(:user1) { build(:user) }
    let(:message) {build(:message)}
    let(:msg) { build(Message.create(body: "test", user: user1)) }

    before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user1)
    end

    context 'Creates message' do
        it 'adds message to database' do
            # expect(msg).to change(Message.count)
        end
    end
end
