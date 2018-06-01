class PagesController < ApplicationController
  before_action :authenticate_user!
  def index
    respond_to do |format|
      format.html { render(:text => "not implemented") }
      format.js
    end
  end
end