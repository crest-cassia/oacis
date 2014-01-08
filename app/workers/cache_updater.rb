class CacheUpdater
  MAX_PS_NUM_TO_UPDATE = 100

  def self.perform(logger)
    logger.info "updating cache"
    ParameterSet.where(runs_status_count_cache: nil).order_by(:updated_at.asc).limit(MAX_PS_NUM_TO_UPDATE).each do |ps|
      ps.runs_status_count
    end
  rescue => ex
    logger.error("Error in CacheUpdater: #{ex.inspect}")
  end
end
