$(function() {
  var reload_template;

  reload_template = function (default_template) {
    var template = $('textarea#host_template');
    template.text(default_template);
  };

  window.reload_template = reload_template;
});

