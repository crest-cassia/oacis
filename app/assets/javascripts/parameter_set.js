let oFilterTable = null;
let oFilterSetTable = null;

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

function create_filter_list(url) {
  var oFilterTable = $("#parameter_filter_list").DataTable({
/*    data: $("#parameter_filter_list").data('source')*/
      ajax: {
        url: url,
        dataType: "json"
      }
  });
  return oFilterTable;
}

function create_filter_set_list(url) {
  let oFilterSetTable = $("#parameter_filter_set_list").DataTable({
    ajax: {
      url: url,
      dataType: "json"
    }
  });
  return oFilterSetTable;
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

function show_filter_set_name_dlg() {
  $("#parameter_save_filter_set_modal").modal("show");

  $("#parameter_save_filter_set_ok").on("click", function() {
    const name = $("#filter_set_name").val();
    $("#filter_set_name_p").text(name);
    $("#name").val(name);
  });
}

function show_load_filter_set_dlg(obj) {
  const simulator_id = $(obj).attr('simulator_id');
  console.log("show_load_filter_set_dlg:" + simulator_id);
  $("#parameter_load_filter_set_modal").modal("show", {
    simulator_id: simulator_id 
  });
}

function add_new_filter() {
  alert("OK")
  if (oFilterTable == null) {
    alert("Null");
    return;
  }
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
  $('#parameter_filter_modal_btn').on('click', function(){
    const simulator_id = $(this).attr('simulator_id');
    const filter_set_id = $(this).attr('filter_set_id');
    const filter_set_name = $(this).attr('filter_set_name');
    $('#parameter_filter_modal').modal('show', {
      simulator_id: simulator_id,
      filter_set_id: filter_set_id,
      filter_set_name: filter_set_name
    });
  });
  $("#parameter_filter_modal").on('show.bs.modal', function(event) {
    const simulator_id = event.relatedTarget.simulator_id;
    const filter_set_id = event.relatedTarget.filter_set_id;
    const filter_set_name = event.relatedTarget.filter_set_name;
    const url = "/simulators/"+simulator_id+"/_parameter_set_filter_list/"+filter_set_id;
    oFilterTable = create_filter_list(url);
    $("#filter_set_name_p").text(filter_set_name);
    $("#name").val(filter_set_name);
    $("#parameter_new_filter_btn").on("click", function() {
      $("#parameter_new_filter_modal").modal('show');
    });
  });

  $("#parameter_load_filter_set_modal").on('show.bs.modal', function(event) {
    const simulator_id = event.relatedTarget.simulator_id;
    console.log(simulator_id);
    const url = "/simulators/"+simulator_id+"/_filter_set_list"
    oFilterSetTable = create_filter_set_list(url);
  });
});
