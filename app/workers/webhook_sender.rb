class WebhookSender

  def self.perform(logger)
    begin
      Webhook.run
    rescue => ex
      logger.error("Error in WebhookSender: #{ex.inspect}")
    end
  end
end

