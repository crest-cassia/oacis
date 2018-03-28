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
        "targets": [0,1]
      }],
      ajax: $(selector).data('source')
    });
    const aPagePath = $(location).attr('pathname').split('/');
    const actionUrl = '/' +  aPagePath[1] + '/' + aPagePath[2] + '/_delete_selected_runs'
    $(selector+'_length').append(
      '<i class="fa fa-refresh padding-half-em clickable add-margin-bottom" id="runs_list_refresh"></i>'
    );
    $(selector+'_length').parent().after(
    '<div class="dataTables_length" id="selected_runs_ctl_div" style="float: right;">' +
    '<form name="runs_form" id="runs_select_form" action="' + actionUrl + '" method="post">' +
    '<span class="add-margin-top pull-left add-padding-right">Selected <span id="runs_count"></span> Runs</span>' +
    '<input type="hidden" name="id_list" id="run_selected_id_list">' +
    '<input type="button" class="btn btn-primary margin-half-em" value="Delete Selected" id="runs_delete_sel">' +
    '</form>' +
    '</div>'
    );
    $('#runs_count').text('0');
    var refresh_icon = $(selector+'_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false);});
    $('#run_check_all').on('change', function() {
      const checkAll = $('#run_check_all').prop('checked');
      if(checkAll) {
        $('input[name="checkbox[run]"]').prop('checked', true).trigger('change');
      } else {
        $('input[name="checkbox[run]"]').prop('checked', false).trigger('change');
      }
    });
    $(document).on('click', '.span1', function() {
      $('#run_selected_id_list').val('');
      $('#runs_count').text('0');
      $('#run_check_all').prop('checked', false).trigger('change');
    });
    $(document).on('change','input[name="checkbox[run]"]', function() {
      let checkedCnt = 0;
      const numCheckBoxes = $('input[name="checkbox[run]"]').length;
      const idList = $('.dataTable tbody input:checked').map(function() {
        checkedCnt += 1;
        return $(this).val();
      }).get();
      $('#runs_count').text(checkedCnt);
      $('#run_selected_id_list').val(idList);
      setSelectRunsCtlDivDisp(checkedCnt > 0);
      $('#run_check_all').prop('checked', checkedCnt == numCheckBoxes);
    });
    $('#runs_delete_sel').on('click', function() {
      const ret = confirm('Delete selected Runs. Are you sure?');
      if (ret) {
        $('#runs_select_form').submit();
      }
    });
    let setSelectRunsCtlDivDisp = (dispFlag) => {
      if (dispFlag) {
        $('#selected_runs_ctl_div').show();
        $('#runs_list_length').hide();
      }
      else {
        $('#selected_runs_ctl_div').hide();
        $('#runs_list_length').show();
      }
    }
    setSelectRunsCtlDivDisp(false);
    return oTable;
  };
  window.datatables_for_runs_table = datatables_for_runs_table;
});

// This function is used to adjust the size of iframe
function resizeIframe(obj) {
  obj.style.height = obj.contentWindow.document.body.scrollHeight + 'px';
  obj.style.width = obj.contentWindow.document.body.scrollWidth + 'px';
}
