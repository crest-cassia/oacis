class WebhookSender

  def self.perform(logger)
    begin
      Simulator.each do |sim|
        sim.webhook.run
      end
    rescue => ex
      logger.error("Error in WebhookSender: #{ex.inspect}")
    end
  end
end

