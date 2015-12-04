class CacheUpdater
  MAX_PS_NUM_TO_UPDATE = 10

  def self.perform(logger)
    logger.debug "updating cache for parameter sets"
    ParameterSet.or(progress_rate_cache: nil).or(runs_status_count_cache: nil).order_by(:updated_at.asc).limit(MAX_PS_NUM_TO_UPDATE).each do |ps|
      ps.runs_status_count
      logger.info "updated cache for ParameterSet: #{ps.id}"
    end
  rescue => ex
    logger.error("Error in CacheUpdater: #{ex.inspect}")
  end
end
