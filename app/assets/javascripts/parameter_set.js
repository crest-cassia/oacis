function create_parameter_sets_list(selector, default_length) {
  var oPsTable = $(selector).DataTable({
    processing: true,
    serverSide: true,
    searching: false,
    order: [[3, "desc"]],
    autoWidth: false,
    pageLength: default_length,
    lengthMenu: [[10, 25, 50, 100, 200],[10, 25, 50, 100, 200]],
    "columnDefs": [{
      "searchable": false,
      "orderable": false,
      "targets": [0,1]
    }],
    dom: 'C<"clear">lrtip',
    colVis: {
      exclude: [0],
      restore: "show all",
      buttonText: "show/hide columns"
    },
    bStateSave: true,
    ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[data.length-1];
        $(row).attr('id', lnId);
      }
  });
  const actionUrl = '/parameter_sets/_delete_selected';
  const lengthDiv = $(selector+'_length');
  lengthDiv.css('height', '45px');
  setupRefreshTools(oPsTable, lengthDiv);

  lengthDiv.after(
    '<div class="dataTables_length" id="selected_pss_ctl_div" style="height: 45px;">' +
    '<form name="ps_form" id="ps_select_form" action="' + actionUrl + '" method="post">' +
    '<input type="hidden" name="authenticity_token" value="' + $('meta[name="csrf-token"]').attr('content') + '">' +
    '<span class="add-margin-top pull-left">Selected <span id="ps_count"></span>  Parameters Sets</span>' +
    '<input type="hidden" name="id_list" id="ps_selected_id_list">' +
    '<input type="button" class="btn btn-warning margin-half-em" value="Delete" id="ps_delete_sel">' +
    '<input type="button" class="btn btn-primary margin-half-em" value="Create Runs" id="ps_run_sel" data-toggle="modal" data-target="#create_runs_on_selected_modal">' +
    '</form>' +
    '</div>'
  );
  $('#ps_count').text('0');
  $(selector+'_length').children('#list_refresh').on('click', function() {
    oPsTable.ajax.reload(null, false);
  });
  $('#ps_check_all').on('change', function() {
    const checkAll = $('#ps_check_all').prop('checked');
    if(checkAll) {
      $('input[name="checkbox[ps]"]').prop('checked', true).trigger('change');
    } else {
      $('input[name="checkbox[ps]"]').prop('checked', false).trigger('change');
    }
  });
  $(document).on('click', '.span1', function() {
    $('#ps_selected_id_list').val('');
    $('#ps_count').text('0');
    $('#ps_check_all').prop('checked', false).trigger('change');
  });
  $(document).on('change','input[name="checkbox[ps]"]', function() {
    let checked_cnt = 0;
    const num_checkboxes = $('input[name="checkbox[ps]"]').length;
    const id_list = $('.dataTable tbody input:checked').map(function() {
      checked_cnt += 1;
      return $(this).val();
    }).get();
    $('#ps_count').text(checked_cnt);
    $('#ps_selected_id_list').val(id_list);
    setSelectPSCtlDivDisp(checked_cnt > 0);
    $('#ps_check_all').prop('checked', checked_cnt == num_checkboxes);
  });
  $('#ps_delete_sel').on('click', function() {
    const res = confirm('Delete selected Parameter Sets. Are you sure?');
    if (res) {
      $('#ps_select_form').submit();
    }
  });
  let setSelectPSCtlDivDisp = (dispFlag) => {
    if (dispFlag) {
      $('#selected_pss_ctl_div').show();
      $(selector+'_length').hide();
      $('div.ColVis').hide();
    }
    else {
      $('#selected_pss_ctl_div').hide();
      $(selector+'_length').show();
      $('div.ColVis').show();
    }
  }
  setSelectPSCtlDivDisp(false);
  return oPsTable;
}

function create_parameter_set_filters_list(selector, url) {
  const loFilterSetTable = $(selector).DataTable({
    lengthChange: false,
    searching: false,
    serverSide: true,
    pageLength: 10,
    ordering: false,
    ajax: {
      url: url,
      dataType: "json"
    }
  });
  return loFilterSetTable;
}
