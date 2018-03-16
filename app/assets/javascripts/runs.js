$(function() {
  var datatables_for_runs_table = function() {
    var selector='#runs_list';
    var oTable = $(selector).DataTable({
      processing: true,
      serverSide: true,
      searching: false,
      order: [[ 8, "desc" ], [ 1, "desc"]],
      destroy: true,
      "columnDefs": [{
        "searchable": false,
        "orderable": false,
        "targets": [0,-1]
      }],
      ajax: $(selector).data('source')
    });
    $(selector+'_length').append(
      '<i class="fa fa-refresh padding-half-em clickable add-margin-bottom" id="runs_list_refresh"></i>' +
    '<div class="dataTables_length"><span class="add-margin-top pull-left add-padding-right">Selected <span id="runs_count"></span> Runs</span>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="runs_list_select_all">Select/Unselect All</button>' +
    '<button class="ColVis_Button ColVis_MasterButton margin-half-em" id="runs_list_toggle">Toggle Selection</button>' +
    '<form name="runs_form">' +
    '<input type="hidden" name="id">' +
    '<input type="button" class="btn btn-primary margin-half-em" value="Delete Selected" id="runs_delete_sel">' +
    '</form>' +
    '</div>'
    );
    var id = '';
    var checked_cnt = 0;
    var text=document.createTextNode(checked_cnt);
    runs_count.appendChild(text);
    var refresh_icon = $(selector+'_length').children('#runs_list_refresh');
    refresh_icon.on('click', function() { oTable.ajax.reload(null, false);});
    $('#runs_list_select_all').on('click', function() {
      var cb_cnt = $('input[name="checkbox[run]"]').length;
      var checked = 0;
      $('.dataTable input:checked').map(function() {
        checked += 1;
      });
      if(cb_cnt != checked) {
        $('input[name="checkbox[run]"]').prop('checked', true).trigger('change');
      } else {
        $('input[name="checkbox[run]"]').prop('checked', false).trigger('change');
      }
    });
    $('#runs_list_toggle').on('click', function() {
      $('input[name="checkbox[run]"]').prop('checked', function( index, prop ){
        return !prop;
      });
      $('input[name="checkbox[run]"]').trigger('change');
    });
    $(document).on('click', '.span1', function() {
      id = '';
      text = runsCreateTxt("0");
      runs_count.appendChild(text);
    });
    $(document).on('change','input[name="checkbox[run]"]', function() {
      checked_cnt = 0;
      id = $('.dataTable input:checked').map(function() {
        checked_cnt += 1;
        return $(this).val();
      }).get();
      text = runsCreateTxt(checked_cnt);
      runs_count.appendChild(text);
      document.runs_form.id.value = id;
    });
    $('#runs_delete_sel').on('click', function() {
      alert(id);
    });
    return oTable;
  };
  window.datatables_for_runs_table = datatables_for_runs_table;
});

function runsCreateTxt(checked_cnt) {
  var removeObj = document.getElementById("runs_count");
  removeObj.removeChild(removeObj.childNodes.item(0));
  var text=document.createTextNode(checked_cnt);
  return text;
}

// This function is used to adjust the size of iframe
function resizeIframe(obj) {
  obj.style.height = obj.contentWindow.document.body.scrollHeight + 'px';
  obj.style.width = obj.contentWindow.document.body.scrollWidth + 'px';
}
