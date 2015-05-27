$(function () {
  $("#analyses_list").on("click", "i.fa.fa-plus-square-o[analysis_id]", function() {
    var analysis_id = $(this).attr("analysis_id");
    $('#analyses_list_modal').modal("show", {
      analysis_id: analysis_id
    });
  });
  $("#analyses_list_modal").on('show.bs.modal', function (event) {
    var analysis_id = event.relatedTarget.analysis_id;
    $.get("/analyses/"+analysis_id+"/_result", function(data) {
      $("i.fa.fa-plus-square-o[analysis_id="+analysis_id+"]").attr("state", "open");
      $("#analyses_list_modal_page").append(data);
    });
  });

  $("#analyses_list_modal").on('hidden.bs.modal', function (event) {
    $('#analyses_list_modal_page').empty();
    $("i.fa.fa-plus-square-o[analysis_id]").attr("state", "close");
  });
});

var bReloadAnalysesTable = true;
function toggle_auto_reload_analyses_table( flag ) {
  bReloadAnalysesTable = flag && window.bEnableAutoReload;
}

$(function() {
  toggle_auto_reload_analyses_table();
  var oAnalysesTableToReload = null;
  setInterval( function() {
    var num_open = $('#analyses_list i.fa.fa-plus-square-o[state="open"]').length;
    if( bReloadAnalysesTable && num_open === 0 && oAnalysesTableToReload ) { oAnalysesTableToReload.ajax.reload(null, false); }
  }, 5000);

  var datatables_for_analyses_table = function() {
    var oTable = $('#analyses_list').DataTable({
      processing: true,
      serverSide: true,
      bFilter: false,
      destroy: true,
      ajax: $('#analyses_list').data('source')
    });
    $('#analyses_list_length').append(
      '<i class="fa fa-refresh clickable padding-8" id="analyses_list_refresh"></i>'
    );
    var refresh_icon = $('#analyses_list_length').children('#analyses_list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false); });
    oAnalysesTableToReload = oTable;
    return oTable;
  };

  window.datatables_for_analyses_table = datatables_for_analyses_table;
});
