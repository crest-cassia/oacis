App.worker_log = App.cable.subscriptions.create("WorkerLogChannel", {
  connected: function() {
    // Called when the subscription is ready for use on the server
  },

  disconnected: function() {
    // Called when the subscription has been terminated by the server
  },

  received: function(data) {
    console.log(data);
    if(data['submitter']) {
      $('#worker_activity_submitter').text(data['submitter']);
    }
    if(data['observer']) {
      $('#worker_activity_observer').text(data['observer']);
    }
    if(data['service']) {
      $('#worker_activity_service').text(data['service']);
    }
    // Called when there's incoming data on the websocket for this channel
  }
});
