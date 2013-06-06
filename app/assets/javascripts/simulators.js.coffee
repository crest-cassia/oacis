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
      for element in $("a","tbody","#param_list")
        str = jQuery.parseJSON($(element).text())
        $(element).text("")
        if (str.total > 0)
          $(element).append($("<span>").addClass("progress progress-striped"))
          if (str.finished > 0)
            percent = Math.floor(100.0*str.finished/str.total)
            $("span",element).append($("<span>").addClass("bar bar-success").attr({style: "width: "+percent+"%"}).text(percent+"%"))
          if (str.running > 0)
            percent = Math.floor(100.0*str.running/str.total)
            $("span",element).append($("<span>").addClass("bar bar-warning").attr({style: "width: "+percent+"%"}).text(percent+"%"))
          if (str.faild > 0)
            percent = Math.floor(100.0*str.faild/str.total)
            $("span",element).append($("<span>").addClass("bar bar-danger").attr({style: "width: "+percent+"%"}).text(percent+"%"))
        else
          $(element).append(str.id)
