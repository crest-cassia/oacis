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
      ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[12];
        $(row).attr('id', lnId);
      }
    });
    $(selector+'_length').append(
      '<i class="fa fa-refresh padding-half-em auto_reload_setting clickable" id="runs_list_refresh"></i>' +
      '<div class="auto_reload_setting">' +
      '<label class="form-check-label clickable" for="runs_list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="runs_list_refresh_cb" /></label>' +
      '<label for="runs_list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="runs_list_refresh_tb" size="10">sec</label>' +
      '</div>'
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
