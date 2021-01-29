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

(function(){
  let myDefaultWhitelist = $.fn.tooltip.Constructor.DEFAULTS.whiteList;
  myDefaultWhitelist.table = [];
  myDefaultWhitelist.tbody = [];
  myDefaultWhitelist.tr = [];
  myDefaultWhitelist.th = [];
  myDefaultWhitelist.td = [];
})();
