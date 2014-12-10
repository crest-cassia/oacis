$(function () {
  $('body').on("click", 'img[analysis_id]', function() {
    if( $(this).attr("state") === "close" ) {
      var tr_element = $(this).closest("tr");
      var analysis_id = $(this).attr("analysis_id");
      var table_cols = tr_element.children("td").length
      $(this).attr("state", "open").attr("src", "/assets/collapse.png")
      $.get("/analyses/" + analysis_id + "/_result", {}, function(data) {
        tr_element.after(
          $("<tr>").attr("id", "result_" + analysis_id).html(
            $("<td>").attr({colspan: table_cols}).html(
              $("<div>").attr("class", "well").html(data)
            )
          )
        );
      });
    }
    else {  // state === "open"
      $(this).attr("state", "close").attr("src", "/assets/expand.png")
      var result_id = "result_" + $(this).attr("analysis_id")
      $(this).closest("tr").siblings("tr#" + result_id).remove()
    }
  });
});

var bReloadAnalysesTable = true;
function toggle_auto_reload_analyses_table( flag ) {
  bReloadAnalysesTable = flag;
}

$(function() {
  var oAnalysesTableToReload = null;
  setInterval( function() {
    var num_open = $('#analyses_list img.treebtn[state="open"]').length;
    if( bReloadAnalysesTable && num_open == 0 && oAnalysesTableToReload ) { oAnalysesTableToReload.fnReloadAjax(); }
  }, 3000);

  var datatables_for_analyses_table = function() {
    var oTable = $('#analyses_list').dataTable({
      bProcessing: true,
      bServerSide: true,
      bFilter: false,
      bDestroy: true,
      sAjaxSource: $('#analyses_list').data('source'),
      sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>",
      sPaginationType: "bootstrap"
    });
    $('#analyses_list_length').append(
      '<i class="icon-refresh" id="analyses_list_refresh"></i>'
    );
    var refresh_icon = $('#analyses_list_length').children('#analyses_list_refresh');
    refresh_icon.on('click', function() { oTable.fnReloadAjax(); });
    oAnalysesTableToReload = oTable;
    return oTable;
  };

  window.datatables_for_analyses_table = datatables_for_analyses_table;
});
