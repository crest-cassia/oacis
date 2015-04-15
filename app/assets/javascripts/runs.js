var bReloadRunsTable = true;
function toggle_auto_reload_runs_table( flag ) {
  bReloadRunsTable = flag && window.bEnableAutoReload;
}

$(function() {
  toggle_auto_reload_runs_table();
  var oRunsTableToReload = null;
  setInterval( function() {
    if( bReloadRunsTable && oRunsTableToReload ) {
      oRunsTableToReload.fnReloadAjax();
    }
  }, 5000);

  var datatables_for_runs_table = function() {
    var oTable = $('#runs_list').dataTable({
      bProcessing: true,
      bServerSide: true,
      bFilter: false,
      aaSorting: [[ 8, "desc" ]],
      bDestroy: true,
      sAjaxSource: $('#runs_list').data('source')
    });
    $('#runs_list_length').append(
      '<i class="icon-refresh runs-list-refresh" id="runs_list_refresh"></i>'
    );
    var refresh_icon = $('#runs_list_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.fnReloadAjax();});
    oRunsTableToReload = oTable;
    return oTable;
  };

  window.datatables_for_runs_table = datatables_for_runs_table;
});
