function create_parameter_sets_list(selector, default_length) {
  var oPsTable = $(selector).dataTable({
    bProcessing: true,
    bServerSide: true,
    bFilter: false,
    aaSorting: [[ 3, "desc" ]],
    bAutoWidth: false,
    iDisplayLength: default_length,
    sAjaxSource: $(selector).data('source'),
    sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>",
    sPaginationType: "bootstrap"
  });
  $(selector+'_length').append(
    '<i class="icon-refresh" id="params_list_refresh"></i>'
  );
  $('#params_list_length').children('#params_list_refresh').on('click', function() {
    oPsTable.fnReloadAjax();
  });

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
        $("#runs_list" ,tr_element.next()).trigger("change");
      });
    } else {
      $(this)
        .attr("state", "close")
        .attr("src", "/assets/expand.png");
      var run_list = $(this).closest("tr").siblings("tr#ps_"+param_id);
      run_list.remove();
    }
  });
}
