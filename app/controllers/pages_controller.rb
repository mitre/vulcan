# frozen_string_literal: true

# This allows for the home page to have access to all of the messages
class PagesController < ApplicationController
  def home
    current_user&.update_messages_stamp
    @messages = Message.all
    @message = Message.new
  end
end
