let oFilterTable = null;
let oFilterSetTable = null;
let query_id = '';
let isEdit = false;
let isLoaded = false;
const notFilterLabel = 'Not filtering.';

function create_parameter_sets_list(selector, default_length) {
  var oPsTable = $(selector).DataTable({
    processing: true,
    serverSide: true,
    searching: false,
    order: [[3, "desc"]],
    autoWidth: false,
    pageLength: default_length,
    "columnDefs": [{
      "searchable": false,
      "orderable": false,
      "targets": [0,1]
    }],
    dom: 'C<"clear">lrtip',
    colVis: {
      exclude: [0, ($("th", selector).size()-1)],
      restore: "Show All Columns"
    },
    bStateSave: true,
    ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[data.length-1];
        $(row).attr('id', lnId);
      },
      "drawCallback": function(settings) {
        const mess = settings["json"]["message"];
        if (mess.length > 1) {
          $('#datatable_messages').append('<span class="text-danger">'+mess+'</span>');
        }
      }
  });
  const actionUrl = '/parameter_sets/_delete_selected';
  $(selector+'_length').css('height', '45px');
  $(selector+'_length').append(
    '<i class="fa fa-refresh padding-half-em auto_reload_setting clickable" id="params_list_refresh"></i>' +
    '<div class="auto_reload_setting">' +
    '<label class="form-check-label clickable" for="params_list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="params_list_refresh_cb" /></label>' +
    '<label for="params_list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="params_list_refresh_tb" size="10"/>sec</label>' +
    '</div>'
  );
  $(selector+'_length').after(
    '<div class="dataTables_length" id="selected_pss_ctl_div" style="height: 45px;">' +
    '<form name="ps_form" id="ps_select_form" action="' + actionUrl + '" method="post">' +
    '<input type="hidden" name="authenticity_token" value="' + $('meta[name="csrf-token"]').attr('content') + '">' +
    '<span class="add-margin-top pull-left">Selected <span id="ps_count"></span>  Parameters Sets</span>' +
    '<input type="hidden" name="id_list" id="ps_selected_id_list">' +
    '<input type="button" class="btn btn-primary margin-half-em" value="Delete" id="ps_delete_sel">' +
    '<input type="button" class="btn btn-primary margin-half-em" value="Create Runs" id="ps_run_sel" data-toggle="modal" data-target="#create_runs_on_selected_modal">' +
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
function create_filter_list(url) {
      oFilterTable = $("#parameter_filter_list").DataTable({
      lengthChange: false,
      searching: false,
      ordering: false,
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
    ordering: false,
    ajax: {
      url: url,
      dataType: "json"
    },
    drawCallback: function() {
      const name = $('#filter_set_name_p').text();
      if(isLoaded && name != notFilterLabel) {
        $('input:radio[filter_set_name = "' + name + '"]').prop('checked', true);
      }      
    }
  });
  return loFilterSetTable;
}

function edit_filter(obj) {
  isEdit = true;
  const oTr = $(obj).parent().parent()
  const oPQuery = $(oTr).find(".filter_query");
  const query_id = $(oPQuery).attr('id');   
  $("#parameter_new_filter_modal").attr('query_id', query_id); 
  $("#parameter_new_filter_modal").modal('show');
  const setVal = $("#"+query_id).text().split(" ");
  $("#query__param").val(setVal[0]);
  if("==" == setVal[1]){
    $("#query__matcher").val("eq");
  }else if("!=" == setVal[1] ){
    $("#query__matcher").val("ne");
  }else if(">" == setVal[1] ){
    $("#query__matcher").val("gt");
  }else if(">=" == setVal[1] ){
    $("#query__matcher").val("gte");
  }else if("<" == setVal[1] ){
    $("#query__matcher").val("lt");
  }else if("<=" == setVal[1] ){
    $("#query__matcher").val("lte");
  }
  $("#query__value").val(setVal[2]);
}

function delete_filter(filter_key, rownum) {
  let rows = $('#parameter_filter_list tr').length;
      if(window.confirm($(filter_key).text() + '\nAre you sure?')){
        oFilterTable.row(rownum).remove().draw();
      }else{
        return;
      }
  if(!isLoaded && $('#parameter_filter_list tr .dataTables_empty').length > 0){
    $("#filter_set_name_p").text(notFilterLabel);
    return;
  }
  rows = $('#parameter_filter_list tr').length;
  for(let i=0; i<rows-1; i++){
    let data = oFilterTable.row(i).data();
    if(data[0].match("filter_key_" + i)){
      continue;
    }else{
      const now_rows = i + 1;
      const query_txt = $('#filter_key_' + now_rows).text();
      element = $('#filter_key_' + now_rows).get(0);
      element.id = "filter_key_" + i;
      oFilterTable.row(i).data([
        '<p id="filter_key_' + i + '" class="filter_query">' + query_txt + '</p>',
        '<a href="javascript:void(0);" onclick="edit_filter(this)"><i class="fa fa-edit"></a>',
        '<a href="javascript:void(0);" onclick="delete_filter(filter_key_' + rownum +',' + rownum + ')"><i class="fa fa-trash-o"></a>'
      ]).draw();
    }
  }
  if(!isLoaded){
    create_filter_set_name();
  }
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

    const str = $('#parameter_filter_modal_btn').attr('filter_json');
    if(str == null || (str != null && str.length < 1)){
      return false;
    }else{
      $("#filter_query_array").val(str);
      $('#save_filter_set_form').submit();
    }
  });
}

function parameter_filter_dlg_ok() {
  const queries_str = make_queries_str();
  $('#filter_set_name_for_set').val($("#filter_set_name_p").text());
  $("#filter_set_query_for_set").val(queries_str);
  $("#isLoaded").val(isLoaded);
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

  if(!isEdit){
    let rownum = 0;      
    if($('#parameter_filter_list tr .dataTables_empty').length){
      rownum = 0; 
    }else{
      rownum = $('#parameter_filter_list tr').length - 1; 
    }
    if (value.length >0) {
      oFilterTable.row.add([
        '<p id="filter_key_' + rownum + '" class="filter_query">' + paray + " " + matcher + " " + value + '</p>',
        '<a href="javascript:void(0);" onclick="edit_filter(this)"><i class="fa fa-edit"></a>',
        '<a href="javascript:void(0);" onclick="delete_filter(filter_key_' + rownum +',' + rownum + ')"><i class="fa fa-trash-o"></a>'
      ]).draw();
    }
  }else{
    let rows = $('#parameter_filter_list tr').length;
    for(let i=0; i<rows-1; i++){
      const data = oFilterTable.row(i).data();
      if(data[0].match(query_id)){
        oFilterTable.row(i).data([
          '<p id="filter_key_' + i + '" class="filter_query">' + paray + " " + matcher + " " + value + '</p>',
          '<a href="javascript:void(0);" onclick="edit_filter(this)"><i class="fa fa-edit"></a>',
          '<a href="javascript:void(0);" onclick="delete_filter(filter_key_' + i +',' + i + ')"><i class="fa fa-trash-o"></a>'
        ]).draw();
      }else{
        continue;
      }
    }
    isEdit = false;
  }
  if(!isLoaded){
    create_filter_set_name();
  }
}

function parameter_load_filter_set_ok_click() {
  const oSelected = $('input[name="filter_set_rb[]"]:checked');
  if (oSelected == null) {
    return;
  }
  isLoaded = true;
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
      h['enable'] = true;
      h['query'] = oque.text();
      queryArr.push(h);
    }
  );

  const str = JSON.stringify(queryArr);
  return str;
}

function create_filter_set_name() {
  const rows = $('#parameter_filter_list tr').length;
  let filter_set_name = '';
  for(let i=0; i<rows-1; i++){
    filter_set_name += $("#filter_key_" + i).text() + ',';
  }
  filter_set_name = filter_set_name.slice(0,-1);
  $("#filter_set_name_p").text(filter_set_name); 
}

$(function() {
  $('#parameter_filter_modal_btn').on('click', function(){
    const simulator_id = $(this).attr('simulator_id');
    const filter_json = $(this).attr('filter_json');
    const filter_set_name = $(this).attr('filter_set_name');
    const load_status = $(this).attr('isLoaded');
    if(load_status == 'true') {
      isLoaded = true;
    }else{
      isLoaded = false;
    }
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
    let filter_set_name = event.relatedTarget.filter_set_name;
    const filter_json = event.relatedTarget.filter_json
    const url = "/simulators/"+simulator_id+"/_parameter_set_filter_list?filter_set_id="+filter_set_id+"&filter_json="+filter_json;
    oFilterTable = create_filter_list(url);
    if(!isLoaded){
      filter_set_name = '';
      let queries = $.parseJSON(filter_json);
      for(let i=0;i<queries.length; i++){
        filter_set_name += queries[i].query + ',';
      }
      filter_set_name = filter_set_name.slice(0,-1);
      if(filter_set_name.length == 0) filter_set_name = event.relatedTarget.filter_set_name;
    }
    $("#filter_set_name_p").text(filter_set_name);
    $("#name").val(filter_set_name);
    $("#parameter_new_filter_btn").on("click", function() {
      $("#parameter_new_filter_modal").modal('show');
      isEdit = false;
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
  $("#parameter_load_filter_set_modal").on('shown.bs.modal', function(event) {
    const name = $('#filter_set_name_p').text();
    if(isLoaded && name != notFilterLabel) {
      $('input:radio[filter_set_name = "' + name + '"]').prop('checked', true);
    }
  });
  $("#parameter_load_filter_set_modal").on('hide.bs.modal', function(event) {
    oFilterSetTable.destroy();
  });
  $("#parameter_new_filter_modal").on('show.bs.modal', function(event) {
    if ($(this).attr('query_id') != null) {
      query_id = $(this).attr('query_id');
    }
  });
  $(document).on("ajax:complete", '.delete_link', function() {
    $('#parameter_filter_set_list').DataTable().draw();
  });
  $(document).on('confirm:complete', '#delete_filter_set', function(e, answer) {
    if(answer) {
      if("filter_set_name" in  e.currentTarget.attributes){
        const str = e.currentTarget.attributes["filter_set_name"].nodeValue;
        if($('#filter_set_name_p').text() == str) {
          $(location).attr('search', '');
        }
      }
    }
  });
});
