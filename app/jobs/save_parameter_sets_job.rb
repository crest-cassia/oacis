class SaveParameterSetsJob < ApplicationJob
  queue_as :default
  rescue_from(StandardError) do |exeption|
    Resque.logger.error exeption
  end

  def perform(save_task_id)
    save_task = SaveTask.find(save_task_id)
    save_task.make_ps_in_batches
  ensure
    save_task.destroy
  end
end
