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
        str = jQuery.parseJSON($(this).text())
        $(element).text("")
        $.getJSON "/parameter_sets/"+str.id+"/_run_status", (runs)->
          if runs.total > 0
            $(element).append($("<div>").addClass("progress progress-striped"))
            span_element = $("div",element)
            if runs.finished > 0
              percent = Math.floor(100.0*runs.finished/runs.total)
              $(span_element).append($("<div>").addClass("bar bar-success").attr({style: "width: "+percent+"%"}).text(percent+"%"))
            if runs.running > 0
              percent = Math.floor(100.0*runs.running/runs.total)
              $(span_element).append($("<div>").addClass("bar bar-warning").attr({style: "width: "+percent+"%"}).text(percent+"%"))
            if runs.faild > 0
              percent = Math.floor(100.0*runs.faild/runs.total)
              $(span_element).append($("<div>").addClass("bar bar-danger").attr({style: "width: "+percent+"%"}).text(percent+"%"))
          else
            $(element).append(str.id)
