$(function () {
  $(".has_analysis_modal").on("click", "i.fa.fa-search[analysis_id]", function() {
    const analysis_id = $(this).attr("analysis_id");
    $('#analyses_list_modal').modal("show", {
      analysis_id: analysis_id
    });
  });
  $("#analyses_list_modal").on('show.bs.modal', function (event) {
    const analysis_id = event.relatedTarget.analysis_id;
    $.get("/analyses/"+analysis_id+"/_result", function(data) {
      $("#analyses_list_modal_page").append(data);
    });
  });

  $("#analyses_list_modal").on('hidden.bs.modal', function (event) {
    $('#analyses_list_modal_page').empty();
  });
});

(() => {
  const datatables_for_analyses_table = function(selector) {
    const oTable = $(selector).DataTable({
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
      },
      pageLength: 100
    });
    const wrapperDiv = $(selector).closest(selector+'_wrapper');
    const lengthDiv = wrapperDiv.find(selector+'_length');
    OACIS.setupRefreshTools(lengthDiv, function () { oTable.ajax.reload(null, false) });

    return oTable;
  };

  OACIS.datatables_for_analyses_table = datatables_for_analyses_table;
})();
