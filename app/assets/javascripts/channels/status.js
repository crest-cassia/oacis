App.status = App.cable.subscriptions.create("StatusChannel", {
  connected: function() {
  },

  disconnected: function() {
  },

  received: function(data) {
    if(data['save_task_progress']) {
      let target = $('#ps_being_created_'+data['simulator_id']);
      if(target.length) {
        target.html(data['message']);
        let refresh_icon = $('#params_list_length #list_refresh');
        if(refresh_icon.is(':visible')) {
          refresh_icon.trigger('click');
        }
        return;
      }
    }
    const oid = data["id"];
    const status = data["status"];
    const job_updated_at = data["updated_at"];
    const job_id = data["job_id"];
    const ps_id = data["ps_id"];
    const ps_counts = data["ps_counts"];
    const ps_updated_at = data["ps_updated_at"];
    const sim_id = data["sim_id"];
    const sim_counts = data["sim_counts"];
    const sim_updated_at = data["sim_updated_at"];
    let class_tobe = "label-default";
    const run_list_id = "#run_list_" + oid;
    const params_list_id = "#params_list_" + ps_id;
    const analysis_list_id = "#analysis_list_" + oid;
    const simulator_list_id =  "#simulator_" + sim_id;

    if ($(run_list_id).length) { /* run list exists */
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
        case 'failed':
          class_tobe = "label-danger";
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

      const runUpdatedAtTd = $(run_list_id).find(".run_updated_at");
      $(runUpdatedAtTd).text(job_updated_at);

      if (status === 'finished' || status === 'failed') {
        const elapsedTd = $(run_list_id).find(".run_elapsed");
        const versionTd = $(run_list_id).find(".run_version");
        if(data["real_time"]) { $(elapsedTd).text(data["real_time"]); }
        if(data["version"]) { $(versionTd).text(data["version"]); }
      }
    }
    if ($(params_list_id).length){ /* parameter set list exists */
      const psStatusDiv = $(params_list_id).find(".progress");
      if (psStatusDiv.length) {
        let tooltip_h = psStatusDiv.attr("data-original-title")
          .replace(/<span id=\"finished_count">\d+<\/span>/, '<span id="finished_count">'+ps_counts["finished"]+'</span>')
          .replace(/<span id=\"failed_count">\d+<\/span>/, '<span id="failed_count">'+ps_counts["failed"]+'</span>')
          .replace(/<span id=\"running_count">\d+<\/span>/, '<span id="running_count">'+ps_counts["running"]+'</span>')
          .replace(/<span id=\"submitted_count">\d+<\/span>/, '<span id="submitted_count">'+ps_counts["submitted"]+'</span>')
          .replace(/<span id=\"created_count">\d+<\/span>/, '<span id="created_count">'+ps_counts["created"]+'</span>');
        psStatusDiv.attr("data-original-title", tooltip_h);
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
    const psUpdatedAtTd = $(params_list_id).find(".ps_updated_at");
    $(psUpdatedAtTd).text(ps_updated_at);
    }
    if ($(analysis_list_id).length) { /* analyses list exists */
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
        case 'failed':
          class_tobe = "label-danger";
          break;
      }

      const statusDiv = $(analysis_list_id).find(".status-label");
      $(statusDiv).removeClass(function(index, className) {
        return (className.match(/\blabel-\S+/g) || []).join(' ');
      });
      $(statusDiv).addClass(class_tobe);
      $(statusDiv).text(status);

      if (status === 'finished' || status === 'failed') {
        const versionTd = $(analysis_list_id).find(".arn_version");
        if(data["version"]) { $(versionTd).text(data["version"]); }
      }

      const anlUpdatedAtTd = $(analysis_list_id).find(".arn_updated_at");
      $(anlUpdatedAtTd).text(job_updated_at);
    }
    if ($(simulator_list_id).length) { /* simulator list exists */
      const simStatusDiv = $(simulator_list_id).find(".progress");
      if (simStatusDiv.length) {
        let tooltip_h = simStatusDiv.attr("data-original-title")
          .replace(/<span id=\"finished_count">\d+<\/span>/, '<span id="finished_count">'+sim_counts["finished"]+'</span>')
          .replace(/<span id=\"failed_count">\d+<\/span>/, '<span id="failed_count">'+sim_counts["failed"]+'</span>')
          .replace(/<span id=\"running_count">\d+<\/span>/, '<span id="running_count">'+sim_counts["running"]+'</span>')
          .replace(/<span id=\"submitted_count">\d+<\/span>/, '<span id="submitted_count">'+sim_counts["submitted"]+'</span>')
          .replace(/<span id=\"created_count">\d+<\/span>/, '<span id="created_count">'+sim_counts["created"]+'</span>');
        simStatusDiv.attr("data-original-title", tooltip_h);
        let percentSuccess = 0.0;
        let percentDanger = 0.0;
        let percentWarning = 0.0;
        let percentSubmitted = 0.0;
        simStatusDiv.attr("data-original-title", tooltip_h);
        const simTotal = parseFloat(sim_counts["finished"]) + parseFloat(sim_counts["failed"]) + parseFloat(sim_counts["running"]) + parseFloat(sim_counts["submitted"]) + parseFloat(sim_counts["created"]);
        if (simTotal > 0){
          percentSuccess = Math.round(parseFloat(sim_counts["finished"]) / parseFloat(simTotal) *100);
          percentDanger = Math.round(parseFloat(sim_counts["failed"]) / parseFloat(simTotal) *100);
          percentWarning = Math.round(parseFloat(sim_counts["running"]) / parseFloat(simTotal) *100);
          percentSubmitted = Math.round(parseFloat(sim_counts["submitted"]) / parseFloat(simTotal) *100);
        }
        simStatusDiv.find(".progress-bar-success").css("width", String(percentSuccess) + "%");
        simStatusDiv.find(".progress-bar-success").text(String(percentSuccess) + "%");
        simStatusDiv.find(".progress-bar-danger").css("width", String(percentDanger) + "%");
        simStatusDiv.find(".progress-bar-danger").text(String(percentDanger) + "%");
        simStatusDiv.find(".progress-bar-warning").css("width", String(percentWarning) + "%");
        simStatusDiv.find(".progress-bar-warning").text(String(percentWarning) + "%");
        simStatusDiv.find(".progress-bar-info").css("width", String(percentSubmitted) + "%");
        simStatusDiv.find(".progress-bar-info").text(String(percentSubmitted) + "%");
      }
      const simUpdatedAtTd = $(simulator_list_id).find(".sim_updated_at");
      $(simUpdatedAtTd).text(sim_updated_at);
    }
  },

  rejected: function() {
  }
});
