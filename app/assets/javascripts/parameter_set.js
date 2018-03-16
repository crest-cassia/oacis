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
      lengthChange: false,
      searching: false,
      paging: false,
      ajax: {
        url: url,
        dataType: "json"
      }
  });
  return oFilterTable;
}

function create_filter_set_list(url) {
  let loFilterSetTable = $("#parameter_filter_set_list").DataTable({
    lengthChange: false,
    searching: false,
    serverSide: true,
    pageLength: 10,
    ajax: {
      url: url,
      dataType: "json"
    }
  });
  return loFilterSetTable;
}

function edit_filter(obj) {
  const oTr = $(obj).parent().parent()
  const oPQuery = $(oTr).find(".filter_query");
  const query_id = $(oPQuery).attr('id');
    
  $("#parameter_new_filter_modal").attr('query_id', query_id); 
  $("#parameter_new_filter_modal").modal('show');

}

function delete_filter(idx) {
  alert("D: " + idx);

}

function show_filter_set_name_dlg() {
  $("#parameter_save_filter_set_modal").modal("show");
  $("#filter_set_name").val($("#filter_set_name_p").text());

  $("#parameter_save_filter_set_ok").on("click", function() {
    let name = $("#filter_set_name").val();
    if (name == null || (name != null && name.length < 1))
    {
      alert("Please set the Filter Name.");
      return false;
    }
    $("#filter_set_name_p").text(name);
    $("#name").val(name);
    $("#filter_set_name_for_set").val(name);

    const str = make_queries_str();
    $("#filter_query_array").val(str);
    $('#save_filter_set_form').submit();
  });
}

function parameter_filter_dlg_ok() {
  const queries_str = make_queries_str();
  $("#filter_set_query_for_set").val(queries_str);
  $("#set_filter_set_form").submit();
}

function show_load_filter_set_dlg(obj) {
  const simulator_id = $(obj).attr('simulator_id');
  $("#parameter_load_filter_set_modal").modal("show", {
    simulator_id: simulator_id 
  });
}

function add_new_filter() {
  if (oFilterTable == null) {
    return;
  }
  const paray = $("#query__param").val();
  const matcher = $("#query__matcher option:selected").text();
  const value = $("#query__value").val();
  const rownum = oFilterTable.rows().length;
  if (value.length >0) {
    oFilterTable.row.add([
      '<input type="checkbox" id="filter_cb_add" class="filter_enable_cb" value="true" checked="checked">',
      '<p id="filter_key_' + rownum + '" class="filter_query">' + paray + " " + matcher + " " + value + '</p>',
      '<a href="javascript:void(0);" onclick="edit_filter(this)"><i class="fa fa-edit"></a>',
      '<a href="javascript:void(0);" onclick="delete_filter(this)"><i class="fa fa-trash-o"></a>'
    ]).draw();
  }
}

function parameter_load_filter_set_ok_click() {
  const oSelected = $('input[name="filter_set_rb[]"]:checked');
  if (oSelected == null) {
    return;
  }
  const filter_set_id = oSelected.val();
  const filter_set_name = oSelected.attr('filter_set_name');
  const simulator_id = oSelected.attr('simulator_id');
  $("#filter_set_name_p").text(filter_set_name);
  $("#name").val(filter_set_name);
  $("#filter_set_name_for_set").val(filter_set_name);
  $("#filter_set_id").val(filter_set_id);
  const url = "/simulators/"+simulator_id+"/_parameter_set_filter_list?filter_set_id="+filter_set_id
  oFilterTable.ajax.url(url).load();
}

function make_queries_str() {
  const aoTr = $('#parameter_filter_table_body').children('TR');
  let queryArr = new Array();

  $.each(aoTr,
    function(index, elem) {
      const ocb = $(elem).find('.filter_enable_cb');
      const oque = $(elem).find('.filter_query');
      const h = {};
      h['enable'] = ocb.prop('checked');
      h['query'] = oque.text();
      queryArr.push(h);
    }
  );

  const str = JSON.stringify(queryArr);
  return str;
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
    const filter_json = $(this).attr('filter_json');
    const filter_set_name = $(this).attr('filter_set_name');
    $('#parameter_filter_modal').modal('show', {
      simulator_id: simulator_id,
      filter_set_id: "undefined",
      filter_set_name: filter_set_name,
      filter_json: filter_json
    });
  });
  $("#parameter_filter_modal").on('show.bs.modal', function(event) {
    const simulator_id = event.relatedTarget.simulator_id;
    const filter_set_id = event.relatedTarget.filter_set_id;
    const filter_set_name = event.relatedTarget.filter_set_name;
    const filter_json = event.relatedTarget.filter_json
    const url = "/simulators/"+simulator_id+"/_parameter_set_filter_list?filter_set_id="+filter_set_id+"&filter_json="+filter_json;
    oFilterTable = create_filter_list(url);
    $("#filter_set_name_p").text(filter_set_name);
    $("#name").val(filter_set_name);
    $("#parameter_new_filter_btn").on("click", function() {
      $("#parameter_new_filter_modal").modal('show');
    });
  });

  $("#parameter_filter_modal").on('hide.bs.modal', function(event) {
    oFilterTable.destroy();
  });

  $("#parameter_load_filter_set_modal").on('show.bs.modal', function(event) {
    const simulator_id = event.relatedTarget.simulator_id;
    const url = "/simulators/"+simulator_id+"/_filter_set_list"
    oFilterSetTable = create_filter_set_list(url);
  });
  $("#parameter_load_filter_set_modal").on('hide.bs.modal', function(event) {
    oFilterSetTable.destroy();
  });
  $("#parameter_new_filter_modal").on('show.bs.modal', function(event) {
    if ($(this).attr('query_id') != null) {
      alert($(this).attr('query_id'));
    }
  });
});
