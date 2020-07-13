class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_channel"
  end

  def receive(data)
    ActionCable.server.broadcast data
  end

  def send_message(data)
    Message.create(body: data['content'], user: current_user)
  end
end
