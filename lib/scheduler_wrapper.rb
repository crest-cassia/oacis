class SchedulerWrapper

  TYPES = ["none", "torque", "pjm", "pjm_k", "xscheduler"]

  attr_reader :type

  def initialize(host)
    unless TYPES.include?(host.scheduler_type)
      raise ArgumentError.new("type must be selected from #{TYPES.inspect}")
    end
    @type = host.scheduler_type
    @work_base_dir = Pathname.new(host.work_base_dir)
  end

  def submit_command(script, job_parameters = {})
    case @type
    when "none"
      "nohup bash #{script} > /dev/null 2>&1 < /dev/null & basename #{script}"
    when "torque"
      "cd #{@work_base_dir}; qsub #{script}"
    when "pjm"
      "cd #{@work_base_dir}; pjsub #{script}"
    when "pjm_k"
      ". /etc/bashrc; cd #{@work_base_dir}; pjsub #{script} < /dev/null"
    when "xscheduler"
      "xsub #{script} -d #{@work_base_dir} -p #{Shellwords.shellescape(job_parameters.to_json)}"
      # Shellwords.shelljoin(["xsub", script.to_s, "-d", @work_base_dir.to_s, "-p", job_parameters.to_json])
    else
      raise "not supported"
    end
  end

  def parse_jobid_from_submit_command(output)
    case @type
    when "none"
      output.chomp
    when "torque"
      output.chomp
    when "pjm"
      output.chomp
    when "pjm_k"
      #success: out = STDOUT:[INFO] PJM 0000 pjsub Job 2275991 submitted.
      #         rc  = 0
      #failed:  out = [ERR.] PJM 0007 pjsub Staging option error (3).
      #               Refer to the staging information file. (J5333b14881e31ebcd2000001.sh.s2366652)
      #         rc  = 0
      if output =~ /submitted/
        output.split(" ")[5]
      else
        output =~ /\(J(\d|[a-f])+\.sh\.s(\d+)\)/  #=> matches (J5333b14881e31ebcd2000001.sh.s2366652)
        raise "not supported format" unless $2
        $2
      end
    when "xscheduler"
      JSON.load(output.chomp)["job_id"]
    else
      raise "not supported"
    end
  end

  def get_host_parameters_command
    if @type == "xscheduler"
      "xsub -t"
    else
      raise "invalid"
    end
  end

  def all_status_command
    case @type
    when "none"
      "ps ux"
    when "torque"
      "qstat; pbsnodes -a"
    when "pjm", "pjm_k"
      "pjstat"
    when "xscheduler"
      "xstat"
    else
      raise "not supported"
    end
  end

  def status_command(job_id)
    case @type
    when "none"
      "ps ux | grep \"[#{job_id[0]}]#{job_id[1..-1]}\""
    when "torque"
      "qstat #{job_id}"
    when "pjm", "pjm_k"
      "pjstat #{job_id}"
    when "xscheduler"
      "xstat #{job_id}"
    else
      raise "not supported"
    end
  end

  def parse_remote_status(stdout)
    return :unknown if stdout.empty?
    case @type
    when "none"
      if stdout.present?
        :running
      end
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
    when "pjm", "pjm_k"
      stat = stdout.lines.to_a.last.split[3]
      case stat
      when /ACC|QUE/
        :submitted
      when /SIN|RDY|RNA|RUN|RNO|SOT/
        :running
      when /EXT|CCL/
        :includable
      else
        :unknown
      end
    when "xscheduler"
      case JSON.load(stdout)["status"]
      when "queued"
        :submitted
      when "running"
        :running
      when "finished"
        :includable
      else
        raise "unknown status"
      end
    else
      raise "not supported"
    end
  end

  def cancel_command(job_id)
    case @type
    when "none"
      "kill -- -`ps x -o \"pgid pid command\" | grep \"[#{job_id[0]}]#{job_id[1..-1]}\" | awk '{print $1}'`"
    when "torque"
      "qdel #{job_id}"
    when "pjm", "pjm_k"
      "pjdel #{job_id}"
    when "xscheduler"
      "xdel #{job_id}"
    else
      raise "not supported"
    end
  end

  def scheduler_log_file_paths(run)
    paths = []
    dir = Pathname.new(@work_base_dir)
    case @type
    when "none"
      # No log-file is created
    when "torque"
      paths << dir.join("#{run.id}.sh.o#{run.job_id.to_i}") # run.job_id = 12345.host
      paths << dir.join("#{run.id}.sh.e#{run.job_id.to_i}")
    when "pjm"
      paths << dir.join("#{run.id}.sh.o#{run.job_id}")
      paths << dir.join("#{run.id}.sh.e#{run.job_id}")
      paths << dir.join("#{run.id}.sh.i#{run.job_id}")
    when "pjm_k"
      paths << dir.join("J#{run.id}.sh.o#{run.job_id}")
      paths << dir.join("J#{run.id}.sh.e#{run.job_id}")
      paths << dir.join("J#{run.id}.sh.i#{run.job_id}")
      paths << dir.join("J#{run.id}.sh.s#{run.job_id}")
    when "xscheduler"
      # TODO
    else
      raise "not supported type"
    end
    paths
  end
end
