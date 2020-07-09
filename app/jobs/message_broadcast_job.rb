class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    # ActionCable.server.broadcast 'room_channel', message: render_message(message)
    # puts("test")
    # message.joins(user).save
    # puts(message.to_json)
    ActionCable.server.broadcast "notifications_channel", {
      message: message.to_json(:include => :user)
      # message: message.merge!(user: user).to_json
    }
    puts(message.to_json(:include => :user))
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
