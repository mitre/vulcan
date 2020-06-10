# frozen_string_literal: true

# This is the base controller for the application. Things should only be
# placed here if they are shared between multiple controllers
class ApplicationController < ActionController::Base
  helper :all

  before_action :setup_navigation, :authenticate_user!

  private

  def setup_navigation
    @navigation = []
    @navigation += helpers.base_navigation if current_user
  end
end
