class PagesController < ApplicationController
  def home
    @messages = Message.all
    @message = Message.new
  end
end
