class PagesController < ApplicationController
  def index
    load_and_authorize_resource
    respond_to do |format|
      format.html { render(text: 'not implemented') }
      format.js
    end
  end
end
