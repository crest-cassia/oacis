class Host
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :hostname, type: String
  field :user, type: String
  field :port, type: Integer, default: 22
  field :ssh_key, type: String, default: '~/.ssh/id_rsa'
  field :show_status_command, type: String, default: 'ps au'
  field :submission_command, type: String, default: 'nohup'
  field :work_base_dir, type: String, default: '~'
  field :max_num_jobs, type: Integer, default: 1
  field :script_header_template, type: String, default: JobScriptUtil::DEFAULT_HEADER

  has_and_belongs_to_many :executable_simulators, class_name: "Simulator", inverse_of: :executable_on

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :hostname, presence: true, format: {with: /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/}
  # See http://stackoverflow.com/questions/1418423/the-hostname-regex for the regexp of the hsotname

  validates :user, presence: true, format: {with: /^[A-Za-z0-9]+(?:[ _-][A-Za-z0-9]+)*$/}
  # See http://stackoverflow.com/questions/1221985/how-to-validate-a-user-name-with-regex

  validates :port, numericality: {greater_than_or_equal_to: 1, less_than: 65536}
  validates :max_num_jobs, numericality: {greater_than_or_equal_to: 0}

  CONNECTION_EXCEPTIONS = [
    Errno::ECONNREFUSED,
    Errno::ENETUNREACH,
    SocketError,
    Net::SSH::Exception,
    OpenSSL::PKey::RSAError
  ]

  public
  # return true if connection established, return true
  # return false otherwise
  # connection exception is stored in @connection_error
  def connected?
    start_ssh {|ssh| } # do nothing
  rescue *CONNECTION_EXCEPTIONS => ex
    @connection_error = ex
    return false
  else
    return true
  end

  attr_reader :connection_error

  def status
    ret = nil
    start_ssh do |ssh|
      ret = SSHUtil.execute(ssh, show_status_command).chomp if show_status_command.present?
    end
    return ret
  end

  def submittable_runs
    Run.where(status: :created).in(simulator: executable_simulator_ids).in(submitted_to: [self, nil])
  end

  def submitted_runs
    Run.where(submitted_to: self).in(status: [:submitted, :running, :cancelled])
  end

  def submit(runs)
    start_ssh do |ssh|
      # copy job_script and input_json files
      job_script_paths = prepare_job_script_for(runs)

      # enqueue jobs
      job_script_paths.each do |run_id, path|
        run = Run.find(run_id)
        SSHUtil.execute(ssh, "chmod +x #{path}")
        submit_command = "#{submission_command} #{path}"
        SSHUtil.execute_in_background(ssh, submit_command)
        run.status = :submitted
        run.submitted_to = self
        run.submitted_at = DateTime.now
        run.save!
      end
      job_script_paths
    end
  end

  def check_submitted_job_status
    return if submitted_runs.count == 0
    start_ssh do |ssh|
      # check if job is finished
      submitted_runs.each do |run|
        case remote_status(run)
        when :submitted
          # DO NOTHING
        when :running
          if run.status == :submitted
            run.status = :running
            run.save
          end
        when :includable
          unless run.status == :cancelled
            rpath = result_file_path(run)
            base = File.basename(rpath)
            SSHUtil.download(ssh, rpath, run.dir.join('..', base))
            JobScriptUtil.expand_result_file_and_update_run(run)
            run.reload
            run.enqueue_auto_run_analyzers
          end
          SSHUtil.rm_r(ssh, result_file_path(run))
          SSHUtil.rm_r(ssh, job_script_path(run) ) unless run.status == :failed
          if run.status == :cancelled
            run.submitted_to = nil
            run.destroy
          end
        end
      end
    end
  end

  private
  def start_ssh
    if @ssh
      yield @ssh
    else
      Net::SSH.start(hostname, user, password: "", timeout: 1, keys: ssh_key, port: port) do |ssh|
        @ssh = ssh
        begin
          yield ssh
        ensure
          @ssh = nil
        end
      end
    end
  end

  def prepare_job_script_for(runs)
    script_paths = {}
    start_ssh do |ssh|
      runs.each do |run|
        # prepare job script
        spath = job_script_path(run)
        SSHUtil.write_remote_file(ssh, spath, JobScriptUtil.script_for(run, self))
        script_paths[run.id] = spath

        # prepare _input.json
        input = run.command_and_input[1]
        SSHUtil.write_remote_file(ssh, input_json_path(run), input.to_json) if input
      end
    end
    script_paths
  end

  def job_script_path(run)
    Pathname.new(work_base_dir).join("#{run.id}.sh")
  end

  def input_json_path(run)
    Pathname.new(work_base_dir).join("#{run.id}_input.json")
  end

  def work_dir_path(run)
    Pathname.new(work_base_dir).join("#{run.id}")
  end

  def result_file_path(run)
    Pathname.new(work_base_dir).join("#{run.id}.tar.bz2")
  end

  def remote_status(run)
    status = :submitted
    start_ssh {|ssh|
      if SSHUtil.exist?(ssh, work_dir_path(run))
        status = :running
      elsif SSHUtil.exist?(ssh, result_file_path(run) )
        status = :includable
      end
    }
    status
  end
end
