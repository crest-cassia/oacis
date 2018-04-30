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
    setupRefreshTools(oTable, lengthDiv);

    return oTable;
  };

  window.datatables_for_analyses_table = datatables_for_analyses_table;
});
