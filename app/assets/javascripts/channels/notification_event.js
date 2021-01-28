function create_subscription_to_notification_event_channel() {
  App.notification_event = App.cable.subscriptions.create('NotificationEventChannel', {
    connected: function () {
      // Called when the subscription is ready for use on the server
    },

    disconnected: function () {
      // Called when the subscription has been terminated by the server
    },

    received: function (data) {
      if (data['notification_event']) {
        $('#no-notification-event').hide();
        const item = $(data['notification_event']).hide().fadeIn(1000).css('display', 'block');
        $('#notification-event-list').prepend(item);
      }
      if (data['unread_count'] && data['unread_count'] > 0) {
        $('#notification-event-dropdown .badge').text(data['unread_count']);
      } else {
        $('#notification-event-dropdown .badge').empty();
      }
      if ($('#notification-event-dropdown').hasClass('open')) {
        this.read_all();
      }
      // Called when there's incoming data on the websocket for this channel
    },

    read_all: function () {
      this.perform('read_all');
    }
  });
}
