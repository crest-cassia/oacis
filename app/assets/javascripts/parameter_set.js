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
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-half-em clickable add-margin-bottom" id="params_list_refresh"></i>' +
    '<div class="dataTables_length"><span class="add-margin-top pull-left">Selected <span id="ps_count"></span>  Parameters Sets</span>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="params_list_select_all">Select/Unselect All</button>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="params_list_toggle">Toggle Selection</button>' +
    '<form name="ps_form">' +
    '<input type="hidden" name="id">' +
    '<input type="button" class="btn btn-primary margin-half-em pull-right" value="Delete Selected" id="ps_delete_sel">' +
    '<input type="button" class="btn btn-primary margin-half-em pull-right" value="Run Selected" id="ps_run_sel">' +
    '</form>' +
    '</div>'
  );
  var id = '';
  var checked_cnt = 0;
  var text=document.createTextNode(checked_cnt);
  ps_count.appendChild(text);
  $(selector+'_length').children('#params_list_refresh').on('click', function() {
    oPsTable.ajax.reload(null, false);
  });
  $('#params_list_select_all').on('click', function() {
    var cb_cnt = $('input[name="checkbox[ps]"]').length;
    var checked = 0;
    $('.dataTable input:checked').map(function() {
      checked += 1; 
    });
    if(cb_cnt != checked) {
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
    id = '';
    text = psCreateTxt("0");
    ps_count.appendChild(text);
  });
  $(document).on('change','input[name="checkbox[ps]"]', function() {
    checked_cnt = 0;
    id = $('.dataTable input:checked').map(function() {
      checked_cnt += 1;
      return $(this).val();
    }).get();
    text = psCreateTxt(checked_cnt);
    ps_count.appendChild(text);
    document.ps_form.id.value = id;
  });
  $('#ps_run_sel').on('click', function() {
    alert(id);
  });
  $('#ps_delete_sel').on('click', function() {
    alert(id);
  });
  $(selector).on("click", "i.fa.fa-search[parameter_set_id]", function() {
    var param_id = $(this).attr("parameter_set_id");
    $('#runs_list_modal').modal("show", {
      parameter_set_id: param_id
    });
  });
  return oPsTable;
}

function psCreateTxt(checked_cnt) {
  var removeObj = document.getElementById("ps_count");
  removeObj.removeChild(removeObj.childNodes.item(0));
  var text=document.createTextNode(checked_cnt);
  return text;
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
