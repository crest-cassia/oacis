function create_parameter_sets_list(selector, default_length) {
  var oPsTable = $(selector).DataTable({
    processing: true,
    serverSide: true,
    searching: false,
    order: [[ 3, "desc" ]],
    autoWidth: false,
    pageLength: default_length,
    "columnDefs": [{
      "searchable": false,
      "orderable": false,
      "targets": [0, -1]
    }],
    dom: 'C<"clear">lrtip',
    colVis: {
      exclude: [0, ($("th", selector).size()-1)],
      restore: "Show All Columns"
    },
    bStateSave: true,
    ajax: $(selector).data('source')
  });
  const aPagePath = $(location).attr('pathname').split('/');
  const actionUrl = '/' + aPagePath[1] + '/' + aPagePath[2] + '/_delete_selected_parameter_sets'
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-half-em clickable add-margin-bottom" id="params_list_refresh"></i>'
  );
  $(selector+'_length').after(
    '<div class="dataTables_length" id="selected_pss_ctl_div" style="width: 100%;">' +
    '<span class="add-margin-top pull-left">Selected <span id="ps_count"></span>  Parameters Sets</span>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="params_list_select_all">Select/Unselect All</button>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="params_list_toggle">Toggle Selection</button>' +
    '<form name="ps_form" id="ps_select_form" action="' + actionUrl + '" method="post">' +
    '<input type="hidden" name="id_list" id="ps_selected_id_list">' +
    '<input type="button" class="btn btn-primary margin-half-em" style="float: right;" value="Delete Selected" id="ps_delete_sel">' +
    '<input type="button" class="btn btn-primary margin-half-em" style="float: right;" value="Run Selected" id="ps_run_sel" data-toggle="modal" data-target="#run_selected_modal">' +
    '</form>' +
    '</div>'
  );
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
  $('#params_list_toggle').on('click', function() {
    $('input[name="checkbox[ps]"]').prop('checked', function( index, prop ){
      return !prop;
    });
    $('input[name="checkbox[ps]"]').trigger('change');
  });
  $(document).on('click', '.span1', function() {
    $('#ps_selected_id_list').val('');
    $('#ps_count').text('0');
    $('#ps_check_all').prop('checked', false).trigger('change');
  });
  $(document).on('change','input[name="checkbox[ps]"]', function() {
    let checked_cnt = 0;
    const id_list = $('.dataTable tbody input:checked').map(function() {
      checked_cnt += 1;
      return $(this).val();
    }).get();
    $('#ps_count').text(checked_cnt);
    $('#ps_selected_id_list').val(id_list);
    setSelectPSCtlDivDisp(checked_cnt > 0);
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
