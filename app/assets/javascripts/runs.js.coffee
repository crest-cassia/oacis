# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/
datatables_for_runs_table = ->
  $('#runs_list').dataTable
    bProcessing: true
    bServerSide: true
    bFilter: false
    sAjaxSource: $('#runs_list').data('source')
    sDom: "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>"
    sPaginationType: "bootstrap"

window.datatables_for_runs_table = datatables_for_runs_table