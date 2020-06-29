class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # stream_from "some_channel"
    stream_from "notifications"
    # stop_all_streams
    # stream_from "notifications"
    # ApplicationJob.perform_later("This is a background job")
  end

  def receive(data)
    ActionCable.server.broadcast data
    # alert(data)
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    current_user.messages.create!(field: data['message'], chat_id: data['chat_id'])
  end
end
