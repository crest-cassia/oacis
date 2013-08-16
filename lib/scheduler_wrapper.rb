class SchedulerWrapper

  TYPES = ["none", "torque", "fujitsu FX10"]

  attr_reader :type

  def initialize(type)
    unless TYPES.include?(type)
      raise ArgumentError.new("type must be selected from #{TYPES.inspect}")
    end
    @type = type
  end

  def submit_command(script)
    case @type
    when "torque"
      "qsub #{script}"
    else
      raise "not supported"
    end
  end

  def all_status_command
    case @type
    when "torque"
      "qstat; pbsnodes -a"
    else
      raise "not supported"
    end
  end

  def status_command(job_id)
    case @type
    when "torque"
      "qstat #{job_id}"
    else
      raise "not supported"
    end
  end

  def parse_remote_status(stdout)
    return :unknown if stdout.empty?

    case @type
    when "torque"
      stat = stdout.lines.to_a.last.split[4]
      case stat
      when /Q/
        :submitted
      when /C/
        :includable
      when /[RT]/
        :running
      else
        :unknown
      end
    else
      raise "not supported"
    end
  end

  def cancel_command(job_id)
    case @type
    when "torque"
      "qdel #{job_id}"
    else
      raise "not supported"
    end
  end
end
