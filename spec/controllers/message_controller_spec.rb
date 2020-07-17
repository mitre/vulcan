require 'rails_helper'

RSpec.describe MessagesController do
  include ActiveJob::TestHelper

  let(:user1) { create(:user) }
  let(:message1) {build(:message) }

  before(:each) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user1
  end

  context 'Creates message' do
    it 'adds message to database' do
      # perform_enqueued_jobs do
      #   expect {
      #     # Message.create(body: message1.body, user: user1)
      #     post :create, params: {
      #       message: {
      #         body: message1.body
      #       }
      #     }
      #   }.to change(Message, :count).by 1
        # have_broadcasted_to('notifications_channel')
      # end
    end
  end
end
