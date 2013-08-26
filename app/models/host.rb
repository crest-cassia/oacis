class Host
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :hostname, type: String
  field :user, type: String
  field :port, type: Integer, default: 22
  field :ssh_key, type: String, default: '~/.ssh/id_rsa'
  field :scheduler_type, type: String, default: "none"
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
  validate :work_base_dir_is_not_editable_when_submitted_runs_exist
  validate :template_is_not_editable_when_submittable_runs_exist

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
      wrapper = SchedulerWrapper.new(self.scheduler_type)
      cmd = wrapper.all_status_command
      ret = SSHUtil.execute(ssh, cmd)
    end
    return ret
  end

  def submittable_runs
    Run.where(status: :created, submitted_to: self)
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
        begin
          out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{path}")
          raise "chmod failed : #{rc}, #{err}" unless rc == 0
          cmd = SchedulerWrapper.new(self.scheduler_type).submit_command(path)
          out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
          raise "#{cmd} failed : #{rc}, #{err}" unless rc == 0
          run.status = :submitted
          run.submitted_to = self
          run.job_id = out.chomp
          run.submitted_at = DateTime.now
          run.save!
        rescue => ex
          run.status = :failed
          run.save!
          raise ex
        end
      end
      job_script_paths
    end
  end

  def check_submitted_job_status
    return if submitted_runs.count == 0
    start_ssh do |ssh|
      # check if job is finished
      submitted_runs.each do |run|
        if run.status == :cancelled
          cancel_job(ssh, run)
          remove_remote_files(ssh, run)
          run.submitted_to = nil
          run.destroy
          next
        end
        case remote_status(ssh, run)
        when :submitted
          # DO NOTHING
        when :running
          if run.status == :submitted
            run.status = :running
            run.save
          end
        when :includable, :unknown
          include_result(ssh, run)
        end
      end
    end
  end

  def work_base_dir_is_not_editable?
    self.persisted? and submitted_runs.any?
  end

  def template_is_not_editable?
    self.persisted? and submittable_runs.any?
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

  def cancel_job(ssh, run)
    stat = remote_status(ssh, run)
    if stat == :submitted or stat == :running
      scheduler = SchedulerWrapper.new(scheduler_type)
      cmd = scheduler.cancel_command(run.job_id)
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      $stderr.puts out, err, rc unless rc == 0
    end
  end

  def remote_status(ssh, run)
    status = :unknown
    scheduler = SchedulerWrapper.new(scheduler_type)
    cmd = scheduler.status_command(run.job_id)
    out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
    status = scheduler.parse_remote_status(out) if rc == 0
    status
  end

  def include_result(ssh, run)
    archive = result_file_path(run)
    archive_exist = SSHUtil.exist?(ssh, archive)
    work_dir = work_dir_path(run)
    work_dir_exist = SSHUtil.exist?(ssh, work_dir_path(run))
    if archive_exist and !work_dir_exist           # normal case
      base = File.basename(archive)
      SSHUtil.download(ssh, archive, run.dir.join('..', base))
      JobScriptUtil.expand_result_file_and_update_run(run)
    else
      SSHUtil.download_recursive(ssh, work_dir, run.dir) if work_dir_exist
      run.status = :failed
      run.save!
    end

    remove_remote_files(ssh, run)
    run.enqueue_auto_run_analyzers
  end

  def remove_remote_files(ssh, run)
    paths = [job_script_path(run),
             input_json_path(run),
             work_dir_path(run),
             result_file_path(run),
             Pathname.new(work_base_dir).join("#{run.id}_status.json"),
             Pathname.new(work_base_dir).join("#{run.id}_time.txt"),
             Pathname.new(work_base_dir).join("#{run.id}.tar")
            ]
    paths.each do |path|
      SSHUtil.rm_r(ssh, path) if SSHUtil.exist?(ssh, path)
    end
  end

  def work_base_dir_is_not_editable_when_submitted_runs_exist
    if work_base_dir_is_not_editable? and self.work_base_dir_changed?
      errors.add(:work_base_dir, "is not editable when submitted runs exist")
    end
  end

  def template_is_not_editable_when_submittable_runs_exist
    if template_is_not_editable? and self.script_header_template_changed?
      errors.add(:script_header_template, "is not editable when submittable runs exist")
    end
  end
end
