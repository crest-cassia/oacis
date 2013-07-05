$(function () {
  $('body').on("click", 'img[analysis_id]', function() {
    if( $(this).attr("state") === "close" ) {
      var tr_element = $(this).closest("tr");
      var analysis_id = $(this).attr("analysis_id");
      var table_cols = tr_element.children("td").length
      $(this).attr("state", "open").attr("src", "/assets/collapse.png")
      $.get("/analyses/" + analysis_id + "/_result", {}, function(data) {
        tr_element.after(
          $("<tr>").attr("id", "result_" + analysis_id).html(
            $("<td>").attr({colspan: table_cols}).html(
              $("<div>").attr("class", "well").html(data)
            )
          )
        );
      });
    }
    else {  // state === "open"
      $(this).attr("state", "close").attr("src", "/assets/expand.png")
      var result_id = "result_" + $(this).attr("analysis_id")
      $(this).closest("tr").siblings("tr#" + result_id).remove()
    }
  });
});
