class DocumentDestroyer

  MAX_COUNT_FOR_CHECK_SUB_DOCUMENTS = 10

  def self.perform(logger)
    @skip_count ||= {}
    @logger = logger

    @logger.info "looking for Simulator to be destroyed"
    destroy_documents( Simulator.where(to_be_destroyed: true) )
    @logger.info "looking for ParameterSet to be destroyed"
    destroy_documents( ParameterSet.where(to_be_destroyed: true) )
    @logger.info "looking for Analyzer to be destroyed"
    destroy_documents( Analyzer.where(to_be_destroyed: true) )
    @logger.info "looking for Run to be destroyed"
    destroy_documents(
      Run.where(:to_be_destroyed => true, :status.in => [:finished, :failed])
    )
    @logger.info "looking for Analysis to be destroyed"
    destroy_documents(
      Analysis.where(:to_be_destroyed => true, :status.in => [:finished, :failed])
    )

  rescue => ex
    logger.error("Error in DocumentDestroyer: #{ex.inspect}")
  end

  def self.destroy_documents(query)
    query.each do |obj|
      if obj.destroyable?
        @logger.info "Destroying #{obj.class} #{obj.id}"
        obj.destroy
        @skip_count.delete(obj.id)
      else
        @logger.info "Skip destroying #{obj.class} #{obj.id}. not destroyable yet."
        @skip_count[obj.id] = @skip_count[obj.id].to_i + 1
        if @skip_count[obj.id] >= MAX_COUNT_FOR_CHECK_SUB_DOCUMENTS
          @logger.warn "#{obj.id} has not been destroyable for #{MAX_COUNT_FOR_CHECK_SUB_DOCUMENTS} times"
          @logger.warn "trying to run :set_lower_submittable_to_be_destroyed"
          obj.set_lower_submittable_to_be_destroyed
          @skip_count[obj.id] = 0
        end
      end
    end
  end
end
