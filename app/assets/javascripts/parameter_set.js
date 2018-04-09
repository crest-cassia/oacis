function create_parameter_sets_list(selector, default_length) {
  const bOacisReadOnly = $('#tab-list-parameters').attr('oacis_read_only') == "true"
  const orderColumn = bOacisReadOnly ? 2 : 3
  const orderFalseTargets = bOacisReadOnly ? [0] : [0, 1]
  var oPsTable = $(selector).DataTable({
    processing: true,
    serverSide: true,
    searching: false,
    order: [[ orderColumn, "desc" ]],
    autoWidth: false,
    pageLength: default_length,
    "columnDefs": [{
      "searchable": false,
      "orderable": false,
      "targets": orderFalseTargets
    }],
    dom: 'C<"clear">lrtip',
    colVis: {
      exclude: [0, ($("th", selector).size()-1)],
      restore: "Show All Columns"
    },
    bStateSave: true,
    ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[11];
        $(row).attr('id', lnId);
      }
  });
  const aPagePath = $(location).attr('pathname').split('/');
  const actionUrl = '/' + aPagePath[1] + '/' + aPagePath[2] + '/_delete_selected_parameter_sets'
  $(selector+'_length').css('height', '45px');
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-half-em auto_reload_setting clickable" id="params_list_refresh"></i>' +
    '<div class="auto_reload_setting">' +
    '<label class="form-check-label clickable" for="params_list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="params_list_refresh_cb" /></label>' +
    '<label for="params_list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="params_list_refresh_tb" size="10"/>sec</label>' +
    '</div>'
  );
  if (!bOacisReadOnly){
    $(selector+'_length').after(
      '<div class="dataTables_length" id="selected_pss_ctl_div" style="height: 45px;">' +
      '<form name="ps_form" id="ps_select_form" action="' + actionUrl + '" method="post">' +
      '<input type="hidden" name="authenticity_token" value="' + $('meta[name="csrf-token"]').attr('content') + '">' +
      '<span class="add-margin-top pull-left">Selected <span id="ps_count"></span>  Parameters Sets</span>' +
      '<input type="hidden" name="id_list" id="ps_selected_id_list">' +
      '<input type="button" class="btn btn-primary margin-half-em" value="Delete" id="ps_delete_sel">' +
      '<input type="button" class="btn btn-primary margin-half-em" value="Create Runs" id="ps_run_sel" data-toggle="modal" data-target="#run_selected_modal">' +
      '</form>' +
      '</div>'
    );
  }
  $('#ps_count').text('0');
  $(selector+'_length').children('#params_list_refresh').on('click', function() {
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
  $(selector).on("click", "i.fa.fa-search[parameter_set_id]", function() {
    var param_id = $(this).attr("parameter_set_id");
    $('#runs_list_modal').modal("show", {
      parameter_set_id: param_id
    });
  });
  let setSelectPSCtlDivDisp = (dispFlag) => {
    if (dispFlag) {
      $('#selected_pss_ctl_div').show();
      $('#params_list_length').hide();
      $('div.ColVis').hide();
    }
    else {
      $('#selected_pss_ctl_div').hide();
      $('#params_list_length').show();
      $('div.ColVis').show();
    }
  }
  setSelectPSCtlDivDisp(false);
  return oPsTable;
}

$(function() {
  $("#runs_list_modal").on('show.bs.modal', function (event) {
    var param_id = event.relatedTarget.parameter_set_id;
    $.get("/parameter_sets/"+param_id+"/_runs_and_analyses", function(data) {
      $("#runs_list_modal_page").append(data);
    });
  });

  $("#runs_list_modal").on('hidden.bs.modal', function (event) {
    $('#runs_list_modal_page').empty();
  });
});
