class Host
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :hostname, type: String

  HOST_STATUS = [:enabled, :disabled]

  field :status, type: Symbol, default: HOST_STATUS[0]
  field :user, type: String
  field :port, type: Integer, default: 22
  field :ssh_key, type: String, default: '~/.ssh/id_rsa'
  field :work_base_dir, type: String, default: '~'
  field :mounted_work_base_dir, type: String, default: ""
  field :max_num_jobs, type: Integer, default: 1
  field :polling_interval, type: Integer, default: 60
  field :min_mpi_procs, type: Integer, default: 1
  field :max_mpi_procs, type: Integer, default: 1
  field :min_omp_threads, type: Integer, default: 1
  field :max_omp_threads, type: Integer, default: 1
  field :position, type: Integer # position in the table. start from zero

  has_and_belongs_to_many :executable_simulators, class_name: "Simulator", inverse_of: :executable_on
  has_and_belongs_to_many :executable_analyzers, class_name: "Analyzer", inverse_of: :executable_on
  embeds_many :host_parameter_definitions
  accepts_nested_attributes_for :host_parameter_definitions, allow_destroy: true

  validates :name, presence: true, uniqueness: true, length: {minimum: 1}
  validates :hostname, presence: true, format: {with: /\A(?=.{1,255}$)[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?(?:\.[0-9A-Za-z](?:(?:[0-9A-Za-z]|-){0,61}[0-9A-Za-z])?)*\.?\z/}
  # See http://stackoverflow.com/questions/1418423/the-hostname-regex for the regexp of the hsotname

  validates :user, presence: true, format: {with: /\A[A-Za-z0-9. _-]+\z/}

  validates :port, numericality: {greater_than_or_equal_to: 1, less_than: 65536}
  validates :max_num_jobs, numericality: {greater_than_or_equal_to: 0}
  validates :polling_interval, numericality: {greater_than_or_equal_to: 5}
  validates :min_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :max_mpi_procs, numericality: {greater_than_or_equal_to: 1}
  validates :min_omp_threads, numericality: {greater_than_or_equal_to: 1}
  validates :max_omp_threads, numericality: {greater_than_or_equal_to: 1}
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
    OpenSSL::PKey::RSAError,
    Timeout::Error
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

  def scheduler_status
    ret = nil
    start_ssh do |ssh|
      wrapper = SchedulerWrapper.new(self)
      cmd = wrapper.all_status_command
      ret = SSHUtil.execute(ssh, cmd)
    end
    return ret
  end

  def submittable_runs
    Run.where(status: :created, submitted_to: self)
  end

  def submitted_runs
    Run.unscoped.where(submitted_to: self).in(status: [:submitted, :running])
  end

  def submittable_analyses
    Analysis.where(status: :created, submitted_to: self)
  end

  def submitted_analyses
    Analysis.unscoped.where(submitted_to: self).in(status: [:submitted, :running])
  end

  def runs_status_count
    count = {created: 0, submitted: 0, running: 0, failed: 0, finished: 0}
    Run.collection.aggregate(
      { '$match' => Run.where(submitted_to: self).selector },
      { '$group' => {_id: '$status', count: {'$sum' => 1} } }
    ).each do |h|
      count[ h["_id"] ] = h["count"]
    end
    count
  end

  def work_base_dir_is_not_editable?
    self.persisted? and (submitted_runs.any? or submitted_analyses.any?)
  end

  def destroyable?
    submittable_runs.empty? and submitted_runs.empty? and
    submittable_analyses.empty? and submitted_analyses.empty?
  end

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

  def get_host_parameters
    start_ssh do |ssh|
      cmd = "bash -l -c 'echo XSUB_BEGIN && xsub -t'"
      ## bash -l invokes bash as a login shell.
      ##   This is necessary to load PATH properly from .bash_profile.
      ##   Otherwise, users do not have a way to set PATH in bash.
      ##   .bashrc is not the place to set the PATH
      ##   because only read by a shell that's both interactive and non-login
      ## And sourcing bashrc may print some strings into stdout.
      ##   In order to extract the output of xsub, use 'START_XSUB' as a separator.
      ##   Lines below 'START_XSUB' is the json output written by 'xsub -t'.
      ret = SSHUtil.execute(ssh, cmd).lines.to_a
      begin_idx = ret.index {|line| line =~ /^XSUB_BEGIN$/}
      xsub_out = ret[(begin_idx+1)..-1].join
      self.host_parameter_definitions = JSON.load(xsub_out)["parameters"].reject do |key,val|
        key == "mpi_procs" or key == "omp_threads"
      end.map do |key,val|
        HostParameterDefinition.new(key: key, default: val["default"], format: val["format"])
      end
    end

  rescue => ex
    errors.add(:base, "Error while getting host parameters: #{ex.message}")
  end

  def validate_destroyable
    if destroyable?
      return true
    else
      errors.add(:base, "Created/Submitted Runs exist")
      return false
    end
  end

  def set_position
    self.position = Host.count
  end

  def delete_default_parameters_from_simulator
    self.executable_simulators.each do |sim|
      [:default_host_parameters, :default_mpi_procs, :default_omp_threads].each do |h|
        modified = sim.send(h).delete_if{|key, value| key == id.to_s}
        sim.timeless.update_attribute(:h, modified)
      end
    end
  end
end

