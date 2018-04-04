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
    ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[11];
        $(row).attr('id', lnId);
      }
  });
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-half-em auto_reload_setting clickable" id="params_list_refresh"></i>' +
    '<div class="auto_reload_setting">' +
    '<label class="form-check-label clickable" for="params_list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="params_list_refresh_cb" /></label>' +
    '<label for="params_list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="params_list_refresh_tb" size="10"/>sec</label>' +
    '</div>'
  );
  $(selector+'_length').children('#params_list_refresh').on('click', function() {
    oPsTable.ajax.reload(null, false);
  });

  $(selector).on("click", "i.fa.fa-search[parameter_set_id]", function() {
    var param_id = $(this).attr("parameter_set_id");
    $('#runs_list_modal').modal("show", {
      parameter_set_id: param_id
    });
  });
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
