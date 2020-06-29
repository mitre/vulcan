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
    @m = []
    unless current_user.nil?
      # binding.pry
      @m = Message.where('messages.created_at > :last_sign_in AND messages.user_id != :id', last_sign_in: current_user.last_sign_in_at, id: current_user.id)
      # @m = @m.where('@m.user_id != :id', id: current_user.uid)
    end
  end
end
