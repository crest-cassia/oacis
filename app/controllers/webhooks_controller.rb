class WebhooksController < ApplicationController
  # GET /webhook
  def show
    @webhook = Webhook.first
  end

  # GET /webhook/edit
  def edit
    @webhook = Webhook.first
  end

  # PATCH /webhook.id
  def update
    @webhook = Webhook.first

    if @webhook.update_attributes(permitted_webhook_params)
      redirect_to @webhook, notice: 'Webhook was successfully updated.'
    else
      render action: "edit"
    end
  end

  # POST /webhook/_test
  def _test
    tmp_url = permitted_webhook_params[:webhook_url]
    payload = Webhook::SLACK_PAYLOAD_BASE
    payload["text"] = <<~EOS
      A test message is posted by #oacis[#{`hostname`.strip}].
    EOS
    webhook = Webhook.first
    # there is no tmp_url via test on webhook#show page
    tmp_url = webhook.webhook_url unless tmp_url
    res = webhook.http_post(tmp_url, payload)
    # if res.code != "200"
    #   "implement me to send a message when the url is incollect"
    # end
    head :ok
  end

  # toggle remote scheduler status
  def _toggle_status
    webhook = Webhook.first
    if (webhook.status == :enabled)
      webhook.status = :disabled
      webhook.update_attribute(:status, :disabled)
    else
      webhook.update_attribute(:status, :enabled)
    end

    redirect_back(fallback_location: webhook_path)
  end

  private
  def permitted_webhook_params
    params[:webhook].present? ? params.require(:webhook)
                                   .permit(:webhook_url,
                                           :webhook_condition
                                          ) : {}
  end
end