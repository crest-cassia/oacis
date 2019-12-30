$(function() {
  $('#webhook_test').click(function(){
    $.post( $(this).data('_testUrl'), {"webhook": {"webhook_url": $('#webhook_webhook_url').val()}});
  });
});
