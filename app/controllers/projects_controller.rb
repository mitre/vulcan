class ProjectsController < ApplicationController
    def projects
        @messages = Message.all
        @message = Message.new
    end
end