class NotificationEvent
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :message, type: String
  field :read, type: Boolean, default: false

  scope :unread, -> { where(read: false) }

  after_create do
    ActionCable.server.broadcast 'notification_event', notification_event: render_notification_event, unread_count: self.class.unread.count
    if OacisSetting.instance.webhook_url.present?
      oacis_url = OacisSetting.instance.oacis_url.present? ? OacisSetting.instance.oacis_url : 'http://localhost:3000'
      slack_message = message.gsub(/<a href="(.*)">(.*)<\/a>/) { "<#{File.join(oacis_url, $1)}|#{$2}>" }
      color = slack_message.include?('failed') ? 'danger' : 'good'
      SlackNotifier.new(OacisSetting.instance.webhook_url).notify(message: slack_message, color: color)
    end
  end

  private

  def render_notification_event
    NotificationEventsController.render(partial: 'notification_events/notification_event', locals: { notification_event: self })
  end
end
