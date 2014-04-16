$(function() {
  var load_template;

  load_template = function (default_template) {
    var template = $('textarea#host_template');
    template.text(default_template);
  };

  window.load_template = load_template;
});

