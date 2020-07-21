# frozen_string_literal: true

# This allows for users to subscribe to the Notifications Channel
# As well as it creates and broadcasts messages
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'notifications_channel'
  end

  def receive(data)
    ActionCable.server.broadcast 'notifications_channel', data
  end

  def send_message(data)
    Message.create(body: data['content'], user: current_user)
  end
end
