function create_parameter_sets_list(selector, default_length) {
  var oPsTable = $(selector).DataTable({
    processing: true,
    serverSide: true,
    searching: false,
    order: [[ 3, "desc" ]],
    autoWidth: false,
    pageLength: default_length,
    ajax: $(selector).data('source')
  });
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-8 clickable" id="params_list_refresh"></i>'
  );
  $('#params_list_length').children('#params_list_refresh').on('click', function() {
    oPsTable.ajax.reload(null, false);
  });

  if( window.bEnableAutoReload ) {
    setInterval( function() {
      var num_open = $(selector + ' img.treebtn[state="open"]').length;
      if( num_open == 0 ) { oPsTable.ajax.reload(null, false); }
    }, 5000);
  }

  $(selector).on("click", "img.treebtn[parameter_set_id]", function() {
    var param_id = $(this).attr("parameter_set_id");
    if ($(this).attr("state") == "close") {
      $("img.treebtn[state='open']", $(this).closest("tbody") ).each(function(){
        $(this).trigger("click");
      });
      var tr_element = $(this).closest("tr");
      var table_cols = tr_element.children("td").length;
      $(this)
        .attr("state", "open")
        .attr("src", "/assets/collapse.png");
      $.get("/parameter_sets/"+param_id+"/_runs_and_analyses", function(data) {
        tr_element.after(
          $("<tr>").attr("id", "ps_"+param_id).html(
            $("<td>").attr({colspan: table_cols}).html(
              $("<div>").attr("class", "well").html(data)
            )
          )
        );
        toggle_auto_reload_runs_table(true);
        toggle_auto_reload_analyses_table(true);
      });
    } else {
      $(this)
        .attr("state", "close")
        .attr("src", "/assets/expand.png");
      var run_list = $(this).closest("tr").siblings("tr#ps_"+param_id);
      run_list.remove();
      toggle_auto_reload_runs_table(false);
      toggle_auto_reload_analyses_table(false);
    }
  });
  return oPsTable;
}
