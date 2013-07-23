$(function() {
  var datatables_for_runs_table;

  datatables_for_runs_table = function() {
    return $('#runs_list').dataTable({
      bProcessing: true,
      bServerSide: true,
      bFilter: false,
      sAjaxSource: $('#runs_list').data('source'),
      sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>",
      sPaginationType: "bootstrap"
    });
  };

  window.datatables_for_runs_table = datatables_for_runs_table;

});

var aoRunsTables = [];
function reload_runs_table() {
  aoRunsTables.forEach( function(oTable) {
    oTable.fnReloadAjax();
  });
}
