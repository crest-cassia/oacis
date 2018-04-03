App.status = App.cable.subscriptions.create("StatusChannel", {
  connected: function() {
  },

  disconnected: function() {
  },

  received: function(data) {
    const oid = data["id"];
    const status = data["status"];
    const job_id = data["job_id"];
    const ps_id = data["ps_id"];
    const ps_counts = data["ps_counts"];
    let class_tobe = "label-default";
    const run_list_id = "#run_list_" + oid;
    const params_list_id = "#params_list_" + ps_id;
    const analysis_list_id = "#analysis_list_" + oid;

    if ($(run_list_id) != null && $(run_list_id).is(":visible")) { /* run list is active */
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
    
      const statusDiv = $(run_list_id).find(".status-label");
      $(statusDiv).removeClass(function(index, className) {
        return (className.match(/\blabel-\S+/g) || []).join(' ');
      });
      $(statusDiv).addClass(class_tobe);
      $(statusDiv).text(status);

      const jobIdTd = $(run_list_id).find(".run_job_id");
      $(jobIdTd).text(job_id);

      if (status === 'finished') {
        const elapsedTd = $(run_list_id).find(".run_elapsed");
        const versionTd = $(run_list_id).find(".run_version");
        $(elapsedTd).text(data["real_time"]);
        $(versionTd).text(data["version"]);
      }
    }
    if ($(params_list_id) != null && $(params_list_id).is(":visible")){ /* parameter set list is active */
      const psStatusTr = $(params_list_id);
      const psStatusDiv = $(params_list_id).find(".progress");
      if (psStatusDiv != null) {
        const tooltip_h = {};
        tooltip_h["finished"] = ps_counts["finished"];
        tooltip_h["failed"] = ps_counts["failed"];
        tooltip_h["running"] = ps_counts["running"];
        tooltip_h["submitted"] = ps_counts["submitted"];
        psStatusDiv.attr("data-original-title", JSON.stringify(tooltip_h));
        let percentSuccess = 0.0;
        let percentDanger = 0.0;
        let percentWarning = 0.0;
        let percentSubmitted = 0.0;
        const psTotal = parseFloat(ps_counts["finished"]) + parseFloat(ps_counts["failed"]) + parseFloat(ps_counts["running"]) + parseFloat(ps_counts["submitted"]) + parseFloat(ps_counts["created"]);
        if (psTotal > 0){
          percentSuccess = Math.round(parseFloat(ps_counts["finished"]) / parseFloat(psTotal) *100);
          percentDanger = Math.round(parseFloat(ps_counts["failed"]) / parseFloat(psTotal) *100);
          percentWarning = Math.round(parseFloat(ps_counts["running"]) / parseFloat(psTotal) *100);
          percentSubmitted = Math.round(parseFloat(ps_counts["submitted"]) / parseFloat(psTotal) *100);
        }
        psStatusDiv.find(".progress-bar-success").css("width", String(percentSuccess) + "%");
        psStatusDiv.find(".progress-bar-success").text(String(percentSuccess) + "%");
        psStatusDiv.find(".progress-bar-danger").css("width", String(percentDanger) + "%");
        psStatusDiv.find(".progress-bar-danger").text(String(percentDanger) + "%");
        psStatusDiv.find(".progress-bar-warning").css("width", String(percentWarning) + "%");
        psStatusDiv.find(".progress-bar-warning").text(String(percentWarning) + "%");
        psStatusDiv.find(".progress-bar-info").css("width", String(percentSubmitted) + "%");
        psStatusDiv.find(".progress-bar-info").text(String(percentSubmitted) + "%");
      }
    }
    if ($(analysis_list_id) != null && $(analysis_list_id).is(":visible")) { /* analyses list is active */
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

      const statusDiv = $(analysis_list_id).find(".status-label");
      $(statusDiv).removeClass(function(index, className) {
        return (className.match(/\blabel-\S+/g) || []).join(' ');
      });
      $(statusDiv).addClass(class_tobe);
      $(statusDiv).text(status);

      if (status === 'finished') {
        const versionTd = $(analysis_list_id).find(".arn_version");
        $(versionTd).text(data["version"]);
      }
    }
  },

  rejected: function() {
  }
});
