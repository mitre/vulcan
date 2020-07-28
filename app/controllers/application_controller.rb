# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all

  before_action :setup_navigation, :authenticate_user!, :load_messages

  private

  def setup_navigation
    @navigation = []
    @navigation += helpers.base_navigation if current_user
  end

  def load_messages
    @msg = []

    return if current_user.nil?

    @msg = Message.where(
      'messages.created_at > :last_veiwed_at', last_veiwed_at: current_user.messages_stamp
    ).where.not(user: current_user)
  end
end
