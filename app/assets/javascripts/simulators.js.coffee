# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
jQuery ->
  $('#param_list').dataTable
    bProcessing: true
    bServerSide: true
    bFilter: false
    sAjaxSource: $('#param_list').data('source')
    sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>"
    sPaginationType: "bootstrap"
    fnDrawCallback: (oSettings)->
      $("a", this).each (i, element)->
        param_id = $(element).attr("href").substr($(element).attr("href").lastIndexOf("/"))
        $(element).text("")
        $.getJSON "/parameter_sets/"+param_id+"/_runs_count", (runs)->
          if runs.total > 0
            $(element).append($("<div>").addClass("progress"))
            div_element = $("div",element)
            if runs.finished > 0
              $(div_element).append($("<span>").addClass("progress progress-success progress-striped active"))
              percent = Math.floor(100.0*runs.finished/runs.total)
              $("span.progress.progress-success.progress-striped.active", div_element).append($("<span>").addClass("bar").attr({style: "width: "+percent+"%"}).text(percent+"%"))
            if runs.running > 0
              $(div_element).append($("<span>").addClass("progress progress-warning progress-striped active"))
              percent = Math.floor(100.0*runs.running/runs.total)
              $("span.progress.progress-warning.progress-striped.active", div_element).append($("<span>").addClass("bar").attr({style: "width: "+percent+"%"}).text(percent+"%"))
            if runs.failed > 0
              $(div_element).append($("<span>").addClass("progress progress-danger progress-striped active"))
              percent = Math.floor(100.0*runs.failed/runs.total)
              $("span.progress.progress-danger.progress-striped.active", div_element).append($("<span>").addClass("bar").attr({style: "width: "+percent+"%"}).text(percent+"%"))
          else
            $(element).append(param_id)
