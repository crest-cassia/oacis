jQuery(function() {
  $("a[rel~=popover], .has-popover").popover();
  $("a[rel~=tooltip], .has-tooltip").tooltip();
});
jQuery(function() {
  $("body").tooltip({
    selector: '[data-toggle="tooltip"]',
    trigger: 'hover'
  });
});
