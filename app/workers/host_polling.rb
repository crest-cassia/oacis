# Shared logic for tasks (JobSubmitter, JobObserver) that periodically poll
# remote hosts. Extend this module in a task class.
module HostPolling

  # Iterates over enabled hosts, skipping hosts whose polling interval has not
  # passed since the last poll. An exception raised while processing one host
  # is logged and does not prevent processing of the remaining hosts.
  def each_host_to_poll(logger)
    @last_performed_at ||= {}
    Host.where(status: :enabled).each do |host|
      break if Worker.term_received?
      next if DateTime.now.to_i - @last_performed_at[host.id].to_i < host.polling_interval
      begin
        yield host
      rescue => ex
        logger.error("Error in #{self.name}: #{ex.inspect}")
        logger.error(ex.backtrace)
      end
      @last_performed_at[host.id] = DateTime.now
    end
  end

  # Returns a logger for SSH debug messages when OACIS_SSH_DEBUG=1, nil otherwise.
  def ssh_debug_logger
    return @ssh_logger unless @ssh_logger.nil?
    return nil unless ENV['OACIS_SSH_DEBUG'] == "1"
    @ssh_logger = Logger.new( Rails.root.join('log/ssh_debug.log') )
    @ssh_logger.level = :debug
    @ssh_logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{self.name}] #{datetime.strftime('%Y-%m-%d %H:%M:%S')} #{severity}: #{msg}\n"
    end
    @ssh_logger.debug("printing SSH debug messages for #{self.name}")
    @ssh_logger
  end
end
