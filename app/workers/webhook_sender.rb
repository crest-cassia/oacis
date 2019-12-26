class WebhookSender

  def self.perform(logger)
    begin
      Simulator.webhook
    rescue => ex
      logger.error("Error in WebhookSender: #{ex.inspect}")
    end
  end
end

