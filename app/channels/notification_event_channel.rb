class NotificationEventChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notification_event"
    broadcast_unread_count
  end

  def unsubscribed
    stop_all_streams
  end

  def read_all
    NotificationEvent.unread.update_all(read: true)
    broadcast_unread_count
  end

  private

  def broadcast_unread_count
    ActionCable.server.broadcast 'notification_event', unread_count: NotificationEvent.unread.count
  end
end
