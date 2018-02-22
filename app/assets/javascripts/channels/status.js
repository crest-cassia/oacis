App.status = App.cable.subscriptions.create("StatusChannel", {
  connected: function() {
    console.log("ready");
  },

  disconnected: function() {
    console.log("disconnected");
  },

  received: function(data) {
    console.log("received" + JSON.stringify(data));
    console.log("received " +  data["id"] + ", " + data["status"]);
    const oid = data["id"];
    const status = data["status"];
    const job_id = data["job_id"];
    let class_tobe = "label-default";

    switch (status) {
      case 'submitted':
        class_tobe = "label-info";
        break;
      case 'running':
        class_tobe = "label-warning";
        break;
      case 'finished':
        class_tobe = "label-success";
        break;
    }
    
    const run_list_id = "#run_list_" + oid;
    if ($(run_list_id) != null) {
      const statusDiv = run_list_id + " td:nth-child(2) span";
      $(statusDiv).removeClass(function(index, className) {
        return (className.match(/\blabel-\S+/g) || []).join(' ');
      });
      $(statusDiv).addClass(class_tobe);
      $(statusDiv).text(status);

      const jobIdTr = run_list_id + " td:nth-child(11)";
      $(jobIdTr).text(job_id);

      if (status === 'finished') {
        const elapsedTr = run_list_id + " td:nth-child(4)";
        const versionTr = run_list_id + " td:nth-child(7)";
        $(elapsedTr).text(data["real_time"]);
        $(versionTr).text(data["version"]);
      }
    }
  },

  rejected: function() {
    console.log("rejected");
  }
});
