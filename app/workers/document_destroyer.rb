class DocumentDestroyer

  def self.perform(logger)
    @skip_count ||= {}
    @logger = logger

    @logger.debug "looking for Simulator to be destroyed"
    destroy_documents( Simulator.where(to_be_destroyed: true) )
    @logger.debug "looking for ParameterSet to be destroyed"
    destroy_documents( ParameterSet.where(to_be_destroyed: true) )
    @logger.debug "looking for Analyzer to be destroyed"
    destroy_documents( Analyzer.where(to_be_destroyed: true) )
    @logger.debug "looking for Run to be destroyed"
    destroy_documents(
      Run.where(:to_be_destroyed => true, :status.in => [:finished, :failed])
    )
    @logger.debug "looking for Analysis to be destroyed"
    destroy_documents(
      Analysis.where(:to_be_destroyed => true, :status.in => [:finished, :failed])
    )

  rescue => ex
    logger.error("Error in DocumentDestroyer: #{ex.inspect}")
  end

  def self.destroy_documents(query)
    query.each do |obj|
      if obj.destroyable?
        @logger.info "destroying #{obj.class} #{obj.id}"
        obj.destroy
        @skip_count.delete(obj.id)
      else
        @logger.info "skip destroying #{obj.class} #{obj.id}. not destroyable yet."
      end
    end
  end
end
