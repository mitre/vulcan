class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    # ActionCable.server.broadcast 'room_channel', message: render_message(message)
    ActionCable.server.broadcast "notifications_channel", {
    	message: message.to_json
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
