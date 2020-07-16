
class MessagesController < ApplicationController
  before_action :authenticate_user!

  # def create
  #   Message.create(message_params, user: current_user)
  # end

  # private
  # def message_params
  #   params.require(:message).permit(:body)
  # end
end
