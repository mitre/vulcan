class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    ActionCable.server.broadcast "notifications_channel", {
      message: message.to_json(:include => :user)
    }
  end

  private

  def render_message(message)
  	MessagesController.render(
  		partial: 'message',
  		locals: {
  			message: message
  		}
  	)
  end
end
