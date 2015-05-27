$(function () {
  $("#analyzers_list").on("click", "i.fa.fa-plus-square-o[analyzer_id]", function() {
    var analyzer_id = $(this).attr("analyzer_id");
    $('#analyzers_list_modal').modal("show", {
      analyzer_id: analyzer_id
    });
  });
  $("#analyzers_list_modal").on('show.bs.modal', function (event) {
    var analyzer_id = event.relatedTarget.analyzer_id;
    $.get("/analyzers/"+analyzer_id+"/_inner_show", function(data) {
      $("i.fa.fa-plus-square-o[analyzer_id="+analyzer_id+"]").attr("state", "open");
      $("#analyzers_list_modal_page").append(data);
    });
  });

  $("#analyzers_list_modal").on('hidden.bs.modal', function (event) {
    $('#analyzers_list_modal_page').empty();
    $("i.fa.fa-plus-square-o[analyzer_id]").attr("state", "close");
  });
});
