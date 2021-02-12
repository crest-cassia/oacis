class SlackNotifier
  def initialize(webhook_url)
    @webhook_url = webhook_url
  end

  def notify(message:, color:)
    return if Rails.env.test?

    begin
      payload = { username: 'Oacis', attachments: [{ text: message, color: color }] }.to_json
      Net::HTTP.post_form(URI(@webhook_url), { payload: payload })
    rescue => e
      Rails.logger.error("Slack notification failed: #{e.message}")
    end
  end
end
