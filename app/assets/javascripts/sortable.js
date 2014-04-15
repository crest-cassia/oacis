$(function() {
  $('.sortable').sortable({
    axis: 'y',
    update: function() {
      $.post( $(this).data('sort-url'), $(this).sortable('serialize') );
    }
  });
});
