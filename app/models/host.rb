class Host
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String

  HOST_STATUS = [:enabled, :disabled]

  field :status, type: Symbol, default: HOST_STATUS[0]
  field :work_base_dir, type: String, default: '~/oacis_work'
  field :mounted_work_base_dir, type: String, default: ""
  field :max_num_jobs, type: Integer, default: 1
  field :polling_interval, type: Integer, default: 5
  field :min_mpi_procs, type: Integer, default: 1
  field :max_mpi_procs, type: Integer, default: 1
  field :min_omp_threads, type: Integer, default: 1
  field :max_omp_threads, type: Integer, default: 1
  field :ssh_backend, type: String, default: "net_ssh" # "net_ssh" or "popen_ssh"
  field :position, type: Integer # position in the table. start from zero

  has_and_belongs_to_many :executable_simulators, class_name: "Simulator", inverse_of: :executable_on
  has_and_belongs_to_many :executable_analyzers, class_name: "Analyzer", inverse_of: :executable_on
  embeds_many :host_parameter_definitions
  accepts_nested_attributes_for :host_parameter_definitions, allow_destroy: true
  has_and_belongs_to_many :host_groups

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :max_num_jobs, numericality: {greater_than_or_equal_to: 0}
  validates :polling_interval, numericality: {greater_than_or_equal_to: 5}
  validates :min_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :max_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :min_omp_threads, numericality: {greater_than_or_equal_to: 1}
  validates :max_omp_threads, numericality: {greater_than_or_equal_to: 1}
  validates :ssh_backend, inclusion: {in: ["net_ssh", "popen_ssh"]}
  validates :status, presence: true,
                     inclusion: {in: HOST_STATUS}
  validate :work_base_dir_is_not_editable_when_submitted_runs_exist
  validate :min_is_not_larger_than_max

  before_validation :get_host_parameters,
               :if => lambda { status == :enabled }
  before_create :set_position
  before_destroy :validate_destroyable, :delete_default_parameters_from_simulator
  after_update :delete_default_parameters_from_simulator,
               :if => lambda { status_changed? and status == :disabled }

  CONNECTION_EXCEPTIONS = [
    Errno::ECONNREFUSED,
    Errno::ENETUNREACH,
    SocketError,
    Net::SSH::Exception,
    PopenSSH::ConnectionError,
    OpenSSL::PKey::RSAError,
    Timeout::Error
  ]

  public
  # API
  def self.find_by_name( host_name )
    found = self.where(name: host_name).first
    raise "Host #{host_name} is not found" unless found
    found
  end

  # return true if connection established, return true
  # return false otherwise
  # connection exception is stored in @connection_error
  def connected?
    start_ssh do |ssh|
      SSHUtil::ShellSession.start(ssh) do |sh|
        out,err,rc = SSHUtil.execute2(sh, "echo OACIS-SSH-CONNECTED")
        unless rc == 0 and out.strip == "OACIS-SSH-CONNECTED"
          raise "SSH connection failed: #{out} #{err} #{rc}"
        end
      end
    end # do nothing
  rescue *CONNECTION_EXCEPTIONS => ex
    @connection_error = ex
    return false
  else
    return true
  end

  attr_reader :connection_error

  def scheduler_status
    ret = nil
    start_ssh_shell do |sh|
      wrapper = SchedulerWrapper.new(self)
      cmd = wrapper.all_status_command
      ret,err,rc = SSHUtil.execute2(sh, cmd)
      raise "`xstat` failed: #{err}" unless rc == 0
    end
    return ret
  end

  def submittable_runs
    Run.where(status: :created).any_of( {submitted_to: self}, {:host_group.in => host_groups.to_a} )
  end

  def submitted_runs
    Run.unscoped.where(submitted_to: self).in(status: [:submitted, :running])
  end

  def submittable_analyses
    Analysis.where(status: :created).any_of( {submitted_to: self}, {:host_group.in => host_groups.to_a} )
  end

  def submitted_analyses
    Analysis.unscoped.where(submitted_to: self).in(status: [:submitted, :running])
  end

  def runs_status_count
    count = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0}
    Run.collection.aggregate([
      { '$match' => Run.where(submitted_to: self).selector },
      { '$group' => {_id: '$status', count: {'$sum' => 1} } }
    ]).each do |h|
      count[ h["_id"] ] = h["count"]
    end
    count
  end

  def default_host_parameters
    host_parameter_definitions.map {|d| [d.key, d.default] }.to_h
  end

  def work_base_dir_is_not_editable?
    self.persisted? and (submitted_runs.any? or submitted_analyses.any?)
  end

  def destroyable?
    submittable_runs.empty? and submitted_runs.empty? and
    submittable_analyses.empty? and submitted_analyses.empty? and
    host_groups.all? {|hg| hg.hosts.count > 1 }
  end

  private
  def start_ssh( ssh_logger: nil )
    if @ssh
      yield @ssh
    else
      ssh_logger.debug("starting SSH: " + self.name ) if ssh_logger
      ssh_module = ssh_backend == "popen_ssh" ? PopenSSH : Net::SSH
      ssh_module.start(name, nil, password: nil, timeout: 1, non_interactive: true, logger: ssh_logger) do |ssh|
        @ssh = ssh
        begin
          yield ssh
        ensure
          @ssh = nil
        end
      end
    end
  end

  public
  def start_ssh_shell( ssh_logger: nil, logger: nil )
    start_ssh(ssh_logger: ssh_logger) do |ssh|
      if @ssh_shell
        yield @ssh_shell
      else
        logger&.debug("starting SSH shell: " + self.name )
        SSHUtil::ShellSession.start(ssh, logger: logger) do |sh|
          @ssh_shell = sh
          begin
            yield sh
          ensure
            @ssh_shell = nil
          end
        end
      end
    end
  end

  private
  def work_base_dir_is_not_editable_when_submitted_runs_exist
    if work_base_dir_is_not_editable? and self.work_base_dir_changed?
      errors.add(:work_base_dir, "is not editable when submitted runs exist")
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

  class XSUB_T_ERROR < StandardError; end

  def get_host_parameters
    if ENV['OACIS_SSH_DEBUG'] == "1"
      ssh_logger = Logger.new( Rails.root.join('log/ssh_debug.log') )
      ssh_logger.level = :debug
      ssh_logger.error("printing SSH debug messages")
    end
    start_ssh_shell(ssh_logger: ssh_logger) do |sh|
      cmd = "xsub -t"
      xsub_out,err,rc = SSHUtil.execute2(sh, cmd)
      raise XSUB_T_ERROR.new(err) unless rc == 0
      json = JSON.load(xsub_out)
      raise unless json
      self.host_parameter_definitions = JSON.load(xsub_out)["parameters"].reject do |key,val|
        key == "mpi_procs" or key == "omp_threads"
      end.map do |key,val|
        HostParameterDefinition.new(key: key, default: val["default"], format: val["format"], options: val["options"].to_a)
      end
    end

  rescue XSUB_T_ERROR => ex
    errors.add(:base, "`xsub -t` failed. Make sure if XSUB is properly installed on the remote host:")
    if ex.message =~ /command not found/
      errors.add(:base, "Remember that PATH must be configured in '~/.bash_profile', not in '~/.bashrc' or '~/.zshrc'")
    end
    errors.add(:base, ex.message)
  rescue *CONNECTION_EXCEPTIONS => ex
    if ex.is_a? SocketError and ex.message =~ /getaddrinfo/
      errors.add(:base, "Hostname `#{name}` is not found. Make sure if the correct address is specified in '~/.ssh/config':")
    else
      errors.add(:base, "Connection failure. Make sure that `ssh #{name}` works without entering a password. Otherwise, check if a correct key is added to ssh-agent by `ssh-add` command:")
    end
    errors.add(:base, ex.message)
  rescue => ex
    errors.add(:base, "Error while getting host parameters: #{ex.message}")
  end

  def validate_destroyable
    if destroyable?
      return true
    else
      errors.add(:base, "Cannot destroy Host.")
      throw(:abort)
    end
  end

  def set_position
    self.position = Host.count
  end

  def delete_default_parameters_from_simulator
    self.executable_simulators.each do |sim|
      [:default_host_parameters, :default_mpi_procs, :default_omp_threads].each do |h|
        modified = sim.send(h).delete_if{|key, value| key == id.to_s}
        sim.timeless.update_attribute(h, modified)
      end
    end
  end
end

