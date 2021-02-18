$(() => {
  function datatables_for_files_table(selector) {
    const oTable = $(selector).DataTable({
      processing: true,
      serverSide: true,
      bFilter: false,
      ordering: false,
      destroy: false,
      ajax: $(selector).data('source'),
      "createdRow": function(row, data, dataIndex) {
        const lnId = data[0];
        $(row).attr('id', lnId);
      },
      pageLength: 100
    });

    return oTable;
  }

  OACIS.datatables_for_files_table = datatables_for_files_table;
});
