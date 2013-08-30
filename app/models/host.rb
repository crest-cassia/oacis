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
  field :min_mpi_procs, type: Integer, default: 1
  field :max_mpi_procs, type: Integer, default: 1
  field :min_omp_threads, type: Integer, default: 1
  field :max_omp_threads, type: Integer, default: 1
  field :template, type: String, default: JobScriptUtil::DEFAULT_TEMPLATE

  has_and_belongs_to_many :executable_simulators, class_name: "Simulator", inverse_of: :executable_on
  embeds_many :host_parameter_definitions
  accepts_nested_attributes_for :host_parameter_definitions, allow_destroy: true

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :hostname, presence: true, format: {with: /^(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?$/}
  # See http://stackoverflow.com/questions/1418423/the-hostname-regex for the regexp of the hsotname

  validates :user, presence: true, format: {with: /^[A-Za-z0-9]+(?:[ _-][A-Za-z0-9]+)*$/}
  # See http://stackoverflow.com/questions/1221985/how-to-validate-a-user-name-with-regex

  validates :port, numericality: {greater_than_or_equal_to: 1, less_than: 65536}
  validates :max_num_jobs, numericality: {greater_than_or_equal_to: 0}
  validates :min_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :max_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :min_omp_threads, numericality: {greater_than_or_equal_to: 1}
  validates :max_omp_threads, numericality: {greater_than_or_equal_to: 1}
  validate :work_base_dir_is_not_editable_when_submitted_runs_exist
  validate :template_is_not_editable_when_submittable_runs_exist
  validate :min_is_not_larger_than_max
  validate :template_conform_to_host_parameter_definitions

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
      runs.each do |run|
        begin
          create_remote_work_dir(ssh, run)
          prepare_input_json(ssh, run)
          execute_pre_process(ssh, run)
          job_script_path = prepare_job_script(ssh, run)
          submit_to_scheduler(ssh, run, job_script_path)
        rescue => ex
          work_dir = work_dir_path(run)
          SSHUtil.download_recursive(ssh, work_dir, run.dir) if SSHUtil.exist?(ssh, work_dir)
          remove_remote_files(ssh, run)
          run.update_attribute(:status, :failed)
          $stderr.puts ex.inspect
        end
      end
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

  def create_remote_work_dir(ssh, run)
    cmd = "mkdir -p #{work_dir_path(run)}"
    out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
    raise "\"#{cmd}\" failed: #{rc}, #{out}, #{err}" unless rc == 0
  end

  def prepare_input_json(ssh, run)
    input = run.input
    SSHUtil.write_remote_file(ssh, input_json_path(run), input.to_json) if input
  end

  def execute_pre_process(ssh, run)
    script = run.simulator.pre_process_script
    if script.present?
      path = pre_process_script_path(run)
      SSHUtil.write_remote_file(ssh, path, script)
      out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{path}")
      raise "chmod failed : #{rc}, #{out}, #{err}" unless rc == 0
      cmd = "cd #{File.dirname(path)} && ./#{File.basename(path)} #{run.args} 1>> _stdout.txt 2>> _stderr.txt"
      out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
      raise "\"#{cmd}\" failed: #{rc}, #{out}, #{err}" unless rc == 0
    end
  end

  def prepare_job_script(ssh, run)
    jspath = job_script_path(run)
    SSHUtil.write_remote_file(ssh, jspath, JobScriptUtil.script_for(run, self))
    out, err, rc, sig = SSHUtil.execute2(ssh, "chmod +x #{jspath}")
    raise "chmod failed : #{rc}, #{out}, #{err}" unless rc == 0
    jspath
  end

  def submit_to_scheduler(ssh, run, job_script_path)
    cmd = SchedulerWrapper.new(self.scheduler_type).submit_command(job_script_path)
    out, err, rc, sig = SSHUtil.execute2(ssh, cmd)
    raise "#{cmd} failed : #{rc}, #{err}" unless rc == 0
    run.status = :submitted
    run.job_id = out.chomp
    run.submitted_at = DateTime.now
    run.save!
  end

  def job_script_path(run)
    Pathname.new(work_base_dir).join("#{run.id}.sh")
  end

  def pre_process_script_path(run)
    work_dir_path(run).join("_preprocess.sh")
  end

  def input_json_path(run)
    work_dir_path(run).join('_input.json')
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
    if template_is_not_editable? and self.template_changed?
      errors.add(:template, "is not editable when submittable runs exist")
    end
  end

  def min_is_not_larger_than_max
    if min_mpi_procs > max_mpi_procs
      errors.add(:max_mpi_procs, "must be larger than min_mpi_procs")
    end
    if min_omp_threads > max_omp_threads
      errors.add(:max_omp_threads, "must be larger than min_omp_threads")
    end
  end

  def template_conform_to_host_parameter_definitions
    invalid = SafeTemplateEngine.invalid_parameters(template)
    if invalid.any?
      errors.add(:template, "invalid parameters #{invalid.inspect}")
      return
    end
    vars = SafeTemplateEngine.extract_parameters(template)
    vars -= JobScriptUtil::DEFAULT_EXPANDED_VARIABLES
    keys = host_parameter_definitions.map {|hpdef| hpdef.key }
    diff = vars.sort - keys.sort
    if diff.any?
      diff.each do |var|
        errors[:base] << "'#{var}' appears in template, but not defined as a host parameter"
      end
    end
    diff = keys.sort - vars.sort
    if diff.any?
      diff.each do |var|
        errors[:base] << "'#{var}' is defined as a host parameter, but does not appear in template"
      end
    end
  end
end
