class SaveParameterSetsJob < ApplicationJob
  queue_as :default
  rescue_from(StandardError) do |exeption|
    Resque.logger.error exeption
  end

  def perform(save_task_id)
    save_task = SaveTask.find(save_task_id)
    save_task.make_ps_in_batches
  ensure
    sim = save_task.simulator
    save_task.destroy
    StatusChannel.broadcast_to('message', OacisChannelUtil.progressSaveTaskMessage(sim))
  end
end
