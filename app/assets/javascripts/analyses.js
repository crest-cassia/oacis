$(function () {
  $(".has_analysis_modal").on("click", "i.fa.fa-search[analysis_id]", function() {
    var analysis_id = $(this).attr("analysis_id");
    $('#analyses_list_modal').modal("show", {
      analysis_id: analysis_id
    });
  });
  $("#analyses_list_modal").on('show.bs.modal', function (event) {
    var analysis_id = event.relatedTarget.analysis_id;
    $.get("/analyses/"+analysis_id+"/_result", function(data) {
      $("#analyses_list_modal_page").append(data);
    });
  });

  $("#analyses_list_modal").on('hidden.bs.modal', function (event) {
    $('#analyses_list_modal_page').empty();
  });
});

$(function() {
  var datatables_for_analyses_table = function(selector) {
    var oTable = $(selector).DataTable({
      processing: true,
      serverSide: true,
      bFilter: false,
      order: [[6, "desc"]],
      destroy: true,
      "columnDefs": [{
        "searchable": false,
        "orderable": false,
        "targets": [0, -1]
      }],
      ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[data.length-1];
        $(row).attr('id', lnId);
      }
    });
    const wrapperDiv = $(selector).closest(selector+'_wrapper');
    const lengthDiv = wrapperDiv.find(selector+'_length');
    lengthDiv.append(
      '<i class="fa fa-refresh clickable padding-half-em reload_icon" id="list_refresh"></i>' +
      '<div class="auto_reload_setting">' +
      '<label class="form-check-label clickable" for="list_refresh_cb">auto reload<input type="checkbox" class="form-check-input" id="list_refresh_cb" /></label>' +
      '<label for="list_refresh_tb"><input type="text" pattern="^[0-9]*$" class="form-control form-control-sm" id="list_refresh_tb" size="10"/>sec</label>' +
      '</div>'
    );
    var refresh_icon = lengthDiv.children('#list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false); });
    return oTable;
  };

  window.datatables_for_analyses_table = datatables_for_analyses_table;
});
