var bReloadRunsTable = true;
function toggle_auto_reload_runs_table( flag ) {
  bReloadRunsTable = flag && window.bEnableAutoReload;
}

$(function() {
  toggle_auto_reload_runs_table();
  var oRunsTableToReload = null;
  setInterval( function() {
    if( bReloadRunsTable && oRunsTableToReload ) {
      oRunsTableToReload.ajax.reload(null, false);
    }
  }, 5000);

  var datatables_for_runs_table = function() {
    var oTable = $('#runs_list').DataTable({
      processing: true,
      serverSide: true,
      searching: false,
      order: [[ 8, "desc" ]],
      destroy: true,
      ajax: $('#runs_list').data('source')
    });
    $('#runs_list_length').append(
      '<i class="fa fa-refresh padding-8 clickable" id="runs_list_refresh"></i>'
    );
    var refresh_icon = $('#runs_list_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false);});
    oRunsTableToReload = oTable;
    return oTable;
  };

  window.datatables_for_runs_table = datatables_for_runs_table;
});
