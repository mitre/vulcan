class MessageBroadcastJob < ApplicationJob
  queue_as :default

  def perform(message)
    ActionCable.server.broadcast "notifications_channel", {
      message: message.to_json(:include => :user)
    }
  end
end
