$(function() {
  var datatables_for_runs_table = function() {
    var selector='#runs_list';
    var oTable = $(selector).DataTable({
      processing: true,
      serverSide: true,
      searching: false,
      order: [[ 8, "desc" ], [ 1, "desc"]],
      destroy: true,
      "columnDefs": [{
        "searchable": false,
        "orderable": false,
        "targets": -1
      }],
      ajax: $(selector).data('source')
    });
    $(selector+'_length').append(
      '<i class="fa fa-refresh padding-half-em clickable" id="runs_list_refresh"></i>'
    );
    var refresh_icon = $(selector+'_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false);});
    return oTable;
  };

  window.datatables_for_runs_table = datatables_for_runs_table;
});

// This function is used to adjust the size of iframe
function resizeIframe(obj) {
  obj.style.height = obj.contentWindow.document.body.scrollHeight + 'px';
  obj.style.width = obj.contentWindow.document.body.scrollWidth + 'px';
}
