class ParameterSetsCreator

  def self.perform(logger)
    SaveTask.all.each do |task|
      begin
        logger.debug("creating PS in batch. Task: #{task.id}")
        task.make_ps_in_batches
        sim = task.simulator
        StatusChannel.broadcast_to('message', OacisChannelUtil.progressSaveTaskMessage(sim, -task.creation_size, -task.creation_size*task.num_runs))
      ensure
        task.destroy
      end
      break if $term_received
    end
  rescue => ex
    logger.error("Error in ParameterSetsCreator: #{ex.inspect}")
  end
end

