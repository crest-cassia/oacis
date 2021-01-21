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
//= require jquery-ui/widgets/sortable
//= require jquery_ujs
//= require bootstrap-sprockets
//= require analyses.js
//= require analyzers.js
//= require bootstrap.js
//= require parameter_set.js
//= require runs.js
//= require simulator.js
//= require files.js
//= require sortable.js
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
//= require dataTables/extras/dataTables.colVis
//= require dynatree/jquery.dynatree
//= require cable.js
//= require channels/status.js
//= require channels/worker_log.js
//= require refresh_datatable.js

// Handle back button issues with Twitter Bootstrap's tab component.
// Based on: http://stackoverflow.com/a/10120221/81769
// It has been changed to avoid the following side effects:
// - Switching tabs was being added to navigation history which is undesirable
//   (Worked around this by using location.replace instead of setting the hash property)
// - Browser scroll position was lost due to fragment navigation
//   (Worked around this by converting #id values to #!id values before navigating.)
$(document).ready(function () {
    if (document.location.hash.substr(0,2) == "#!") {
      $('.nav-tabs a[href="' + document.location.hash.replace('!', '') + '"]').tab('show');
    }

    $('.nav-tabs a').on('shown.bs.tab', function(e) {
      window.location.hash = e.target.hash.replace('#', '#' + '!');
    });
});

// add/remove/Up/Down nested forms

function find_from_parameter_definition_fields(me, offset) {
  var p_lst =  $('.parameter-definition-field');
  var idx, em = null;
  for ( idx = 0; idx < p_lst.length; idx++ ) {
    if ( p_lst[idx] === me ) {
      em = p_lst[idx];
      break;
    }
  }
  if ( em == null ) return null;
  var idx2 = idx + offset;
  if ( idx2 < 0 || idx2 >= p_lst.length ) return null;
  return p_lst[idx2];
}

function exchange_form_order(me, em) {
  var my_name = me.children[0].children[0].children[0].value;
  var my_type = me.children[0].children[1].children[0].value;
  var my_dval = me.children[0].children[2].children[0].value;
  var my_desc = me.children[1].children[0].children[0].value;
  me.children[0].children[0].children[0].value = em.children[0].children[0].children[0].value;
  me.children[0].children[1].children[0].value = em.children[0].children[1].children[0].value;
  me.children[0].children[2].children[0].value = em.children[0].children[2].children[0].value;
  me.children[1].children[0].children[0].value = em.children[1].children[0].children[0].value;
  em.children[0].children[0].children[0].value = my_name;
  em.children[0].children[1].children[0].value = my_type;
  em.children[0].children[2].children[0].value = my_dval;
  em.children[1].children[0].children[0].value = my_desc;
}

$(document).ready( function() {
  $('form').on('click', '.remove_fields', function() {
    var me = $(this).closest('.parameter-definition-field')[0];
    var res = confirm("Are you sure to remove the parameter: " +
                      me.children[0].children[0].children[0].value);
    if ( ! res ) event.preventDefault();
    $(this).closest('.parameter-definition-field').next('input[type=hidden]').val(true);
    $(this).closest('.parameter-definition-field').remove();
  });
  $('form').on('click', '.add_fields', function() {
      var time = new Date().getTime();
      var regexp = new RegExp($(this).data('id'), 'g');
      var position_to_add = $(this);
      if( $('#add_field_here').size() > 0 ) { position_to_add = $('#add_field_here'); }
      position_to_add.before($(this).data('fields').replace(regexp, time));
      event.preventDefault();
  });
  $('form').on('click', '.up_fields', function() {
    var me = $(this).closest('.parameter-definition-field')[0];
    var em = find_from_parameter_definition_fields(me, -1);
    if ( em == null ) return;
    exchange_form_order(me, em);
  });
  $('form').on('click', '.down_fields', function() {
    var me = $(this).closest('.parameter-definition-field')[0];
    var em = find_from_parameter_definition_fields(me, +1);
    if ( em == null ) return;
    exchange_form_order(me, em);
  });
});
