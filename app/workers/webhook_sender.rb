class WebhookSender

  def self.perform(logger)
    begin
      if Webhook.where(status: :enabled).count > 0
        Webhook.run
      end
    rescue => ex
      logger.error("Error in WebhookSender: #{ex.inspect}")
    end
  end
end

