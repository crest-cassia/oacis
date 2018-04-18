class WorkerLogChannel < ApplicationCable::Channel
  def subscribed
    stream_from "worker_log:message"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
