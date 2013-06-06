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
        if (str.finished - 0 + str.running - 0 + str.faild - 0 > 0)
          $(element).append("<span class=\"progress progress-striped\"></span>")
          if (str.finished - 0 > 0)
            $("span",element).append("<span class=\"bar bar-success\" style=\"width: "+str.finished+"%\">"+str.finished+"%</span>")
          if (str.running - 0 > 0)
            $("span",element).append("<span class=\"bar bar-warning\" style=\"width: "+str.running+"%\">"+str.running+"%</span>")
          if (str.faild - 0 > 0)
            $("span",element).append("<span class=\"bar bar-danger\" style=\"width: "+str.faild+"%\">"+str.faild+"%</span>")
        else
          $(element).append(str.id)
