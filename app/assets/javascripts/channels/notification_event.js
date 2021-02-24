(() => {
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

          const eventListEl = $('#notification-event-list');
          const newEventEl = $(data['notification_event']).hide().fadeIn(1000).css('display', 'block');
          eventListEl.prepend(newEventEl);

          const eventsEl = eventListEl.children('.list-group-item');
          if (eventsEl.length > 10) {
            eventsEl.last().remove();
          }
        }

        const eventDropdownEl = $('#notification-event-dropdown');
        const badgeEl = eventDropdownEl.find('.badge');
        if (data['unread_count'] && data['unread_count'] > 0) {
          badgeEl.text(data['unread_count']);
        } else {
          badgeEl.empty();
        }
        if (eventDropdownEl.hasClass('open')) {
          this.read_all();
        }
        // Called when there's incoming data on the websocket for this channel
      },

      read_all: function () {
        this.perform('read_all');
      }
    });
  }

  OACIS.create_subscription_to_notification_event_channel = create_subscription_to_notification_event_channel;
})();
