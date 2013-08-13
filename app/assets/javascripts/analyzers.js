$(function () {
  $('body').on("click", 'img[analyzer_id]', function() {
    if( $(this).attr("state") === "close" ) {
      var tr_element = $(this).closest("tr");
      var analyzer_id = $(this).attr("analyzer_id");
      var table_cols = tr_element.children("td").length
      $(this).attr("state", "open").attr("src", "/assets/collapse.png")
      $.get("/analyzers/" + analyzer_id +"/_inner_show", {}, function(data) {
        tr_element.after(
          $("<tr>").attr("id", "about_" + analyzer_id).html(
            $("<td>").attr({colspan: table_cols}).html(
              $("<div>").attr("class", "well").html(data)
            )
          )
        );
      });
    }
    else {  // state === "open"
      $(this).attr("state", "close").attr("src", "/assets/expand.png")
      var about_id = "about_" + $(this).attr("analyzer_id")
      $(this).closest("tr").siblings("tr#" + about_id).remove()
    }
  });
});