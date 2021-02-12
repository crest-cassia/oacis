class NotificationEventsController < ApplicationController
  def index
    @notification_events = NotificationEvent.all.order(created_at: :desc).limit(100)
  end
end
