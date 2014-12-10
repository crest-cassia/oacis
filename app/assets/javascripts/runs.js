var aoRunsTables = []
function reload_runs_table() {
  aoRunsTables.forEach( function(oTable) {
    oTable.fnReloadAjax();
  });
}

$(function() {
  var datatables_for_runs_table = function() {
    var oTable = $('#runs_list').dataTable({
      bProcessing: true,
      bServerSide: true,
      bFilter: false,
      aaSorting: [[ 8, "desc" ]],
      bDestroy: true,
      sAjaxSource: $('#runs_list').data('source'),
      sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>",
      sPaginationType: "bootstrap"
    });
    $('#runs_list_length').append(
      '<i class="icon-refresh" id="runs_list_refresh"></i>'
    );
    var refresh_icon = $('#runs_list_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.fnReloadAjax();});
    return oTable;
  };

  window.datatables_for_runs_table = datatables_for_runs_table;
});
