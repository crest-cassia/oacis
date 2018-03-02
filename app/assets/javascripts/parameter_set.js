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
    '<i class="fa fa-refresh padding-half-em clickable" id="params_list_refresh"></i>'
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

function create_filter_list() {
  var oFilterTable = $("#parameter_filter_list").DataTable();

  return oFilterTable;
}

function edit_filter(idx) {
  alert("E: " + idx);
  const selector = "filter_key_" + idx;
  const q = $(selector).text();
  const sp = /\s*|\{|\}/;
     
  $("#parameter_new_filter_modal").modal('show');

}

function delete_filter(idx) {
  alert("D: " + idx);

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

$(function() {
  $("#parameter_filter_modal_btn").on("click", function() {
    $("#parameter_filter_modal").modal('show');
  });

  var oFilterTable = create_filter_list();

  $("#parameter_new_filter_btn").on("click", function() {
    $("#parameter_new_filter_modal").modal('show');
  });
  $("#parameter_new_filter_ok").on("click", function(event) {
    const paray = $("#query__param").val();
    const matcher = $("#query__matcher").val();
    const value = $("#query__value").val();
    if (value.length >0) {
      oFilterTable.row.add([
        '<input type="checkbox" id="filter_cb_add" value="true">',
        paray + " " + matcher + " " + value,
        '<i class="fa fa-edit">',
        '<i class="fa fa-trash-o">'
      ]).draw();
    }
  });


});
