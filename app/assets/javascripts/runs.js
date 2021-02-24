(() => {
  function datatables_for_runs_table(selector) {
    const oTable = $(selector).DataTable({
      processing: true,
      serverSide: true,
      searching: false,
      order: [[ 9, "desc" ], [ 1, "desc"]],
      destroy: true,
      "columnDefs": [{
        "orderable": false,
        "targets": 0
      }],
      ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[data.length-1];
        $(row).attr('id', lnId);
      },
      pageLength: 100
    });

    // reload settings
    const wrapperDiv = $(selector).closest(selector+'_wrapper');
    const lengthDiv = wrapperDiv.find(selector+'_length');
    OACIS.setupRefreshTools(lengthDiv, function() { oTable.ajax.reload(null, false) });

    // checkbox settings
    const actionUrl = '/runs/_delete_selected';
    lengthDiv.parent().after(
      '<div class="dataTables_length" id="selected_runs_ctl_div" style="height: 43px; clear: both; padding-left: 15px;">' +
      '<form name="runs_form" id="runs_select_form" action="' + actionUrl + '" method="post">' +
      '<input type="hidden" name="authenticity_token" value="' + $('meta[name="csrf-token"]').attr('content') + '">' +
      '<span class="add-margin-top pull-left add-padding-right">Selected <span id="runs_count">0</span> Runs</span>' +
      '<input type="hidden" name="id_list" id="run_selected_id_list">' +
      '<input type="button" class="btn btn-warning margin-half-em" value="Delete" id="runs_delete_sel">' +
      '</form>' +
      '</div>'
    );
    wrapperDiv.find('#run_check_all').on('change', function() {
      const checkAll = $(this).prop('checked');
      const checkedTargets = $(this).closest('table').find('input[name="checkbox[run]"]');
      if(checkAll) {
        $(checkedTargets).prop('checked', true).trigger('change');
      } else {
        $(checkedTargets).prop('checked', false).trigger('change');
      }
    });
    wrapperDiv.on('change','input[name="checkbox[run]"]', function() {
      let checkedCnt = 0;
      const numCheckBoxes = wrapperDiv.find('input[name="checkbox[run]"]').length;
      const idList = wrapperDiv.find('.dataTable tbody input:checked').map(function() {
        checkedCnt += 1;
        return $(this).val();
      }).get();
      wrapperDiv.find('#runs_count').text(checkedCnt);
      wrapperDiv.find('#run_selected_id_list').val(idList);
      setSelectRunsCtlDivDisp(checkedCnt > 0);
      wrapperDiv.find('#run_check_all').prop('checked', checkedCnt == numCheckBoxes);
    });
    wrapperDiv.find('#runs_delete_sel').on('click', function() {
      const ret = confirm('Delete selected Runs. Are you sure?');
      if (ret) {
        wrapperDiv.find('#runs_select_form').submit();
      }
    });
    let setSelectRunsCtlDivDisp = (dispFlag) => {
      if (dispFlag) {
        wrapperDiv.find('#selected_runs_ctl_div').show();
        lengthDiv.hide();
      }
      else {
        wrapperDiv.find('#selected_runs_ctl_div').hide();
        lengthDiv.show();
      }
    }
    setSelectRunsCtlDivDisp(false);
    return oTable;
  }

  // This function is used to adjust the size of iframe
  function resizeIframe(obj) {
    obj.style.height = obj.contentWindow.document.body.scrollHeight + 'px';
    obj.style.width = obj.contentWindow.document.body.scrollWidth + 'px';
  }

  OACIS.datatables_for_runs_table = datatables_for_runs_table;
  OACIS.resizeIframe = resizeIframe;
})();
