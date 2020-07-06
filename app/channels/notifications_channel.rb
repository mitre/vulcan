class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notifications_channel"
  end

  def receive(data)
    ActionCable.server.broadcast data
    alert(data['message'])
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    alert("speak")
    current_user.messages.create!(field: data['message'], chat_id: data['chat_id'])
    # message = Message.create(body: data['message'])
    # socket = { message: message.body }
    # NotificationsChannel.broadcast_to('notifications_channel', socket)
  end
end
