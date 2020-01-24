class WebhookSender

  def self.perform(logger)
    begin
      Webhook.where(status: :enabled).each do |wh|
        wh.run
      end
    rescue => ex
      logger.error("Error in WebhookSender: #{ex.inspect}")
    end
  end
end

