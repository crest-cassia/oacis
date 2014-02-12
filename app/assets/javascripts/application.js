// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require_tree .
//= require dataTables/jquery.dataTables
//= require dataTables/jquery.dataTables.bootstrap
//= require dataTables/jquery.dataTables.api.fnReloadAjax
//= require datatables_extends
//= require d3

// Handle back button issues with Twitter Bootstrap's tab component.
// Based on: http://stackoverflow.com/a/10120221/81769
// It has been changed to avoid the following side effects:
// - Switching tabs was being added to navigation history which is undesirable
//   (Worked around this by using location.replace instead of setting the hash property)
// - Browser scroll position was lost due to fragment navigation
//   (Worked around this by converting #id values to #!id values before navigating.)
$(document).ready(function () {
    if (location.hash.substr(0,2) == "#!") {
        $("a[href='#" + location.hash.substr(2) + "']").tab("show");
    }
    $("a[data-toggle='tab']").on("shown", function (e) {
        var hash = $(e.target).attr("href");
        if (hash.substr(0,1) == "#") {
            location.replace("#!" + hash.substr(1));
        }
    });
});

// add/remove nested forms
$(document).ready( function() {
  $('form').on('click', '.remove_fields', function() {
    $(this).prev('input[type=hidden]').val('1');
    $(this).closest('fieldset').hide();
    event.preventDefault();
  });
  $('form').on('click', '.add_fields', function() {
      var time = new Date().getTime();
      var regexp = new RegExp($(this).data('id'), 'g');
      var position_to_add = $(this);
      if( $('#add_field_here').size() > 0 ) { position_to_add = $('#add_field_here'); }
      position_to_add.before($(this).data('fields').replace(regexp, time));
      event.preventDefault();
  });
});
