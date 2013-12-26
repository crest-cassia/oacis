class Run
  include Mongoid::Document
  include Mongoid::Timestamps
  field :status, type: Symbol, default: :created
  # either :created, :submitted, :running, :failed, :finished, or :cancelled
  field :seed, type: Integer
  field :hostname, type: String
  field :cpu_time, type: Float
  field :real_time, type: Float
  field :submitted_at, type: DateTime
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :included_at, type: DateTime
  field :result  # can be any type. it's up to Simulator spec
  field :mpi_procs, type: Integer, default: 1
  field :omp_threads, type: Integer, default: 1
  field :host_parameters, type: Hash, default: {}
  field :job_id, type: String
  field :job_script, type: String
  index({ status: 1 }, { name: "run_status_index" })
  belongs_to :parameter_set
  belongs_to :simulator  # for caching. do not edit this field explicitly
  has_many :analyses, as: :analyzable, dependent: :destroy
  belongs_to :submitted_to, class_name: "Host"

  # validations
  validates :status, presence: true,
                     inclusion: {in: [:created,:submitted,:running,:failed,:finished, :cancelled]}
  validates :seed, presence: true, uniqueness: {scope: :parameter_set_id}
  validates :mpi_procs, numericality: {greater_than_or_equal_to: 1, only_integer: true}
  validates :omp_threads, numericality: {greater_than_or_equal_to: 1, only_integer: true}
  validates :submitted_to, presence: true, on: :create  # submitted_to can be nil because a host may be destroyed
  validate :host_parameters_given, on: :create
  validate :host_parameters_format, on: :create
  validate :mpi_procs_is_in_range, on: :create
  validate :omp_threads_is_in_range, on: :create
  # validates only for a new_record
  # because Host#max_mpi_procs, max_omp_threads can change during a job is running

  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  attr_accessible :seed, :mpi_procs, :omp_threads, :host_parameters, :submitted_to

  before_create :set_simulator, :remove_redundant_host_parameters, :set_job_script
  before_save :remove_runs_status_count_cache, :if => :status_changed?
  after_create :create_run_dir
  before_destroy :delete_run_dir, :delete_archived_result_file , :remove_runs_status_count_cache

  public
  def initialize(*arg)
    super
    set_unique_seed
  end

  def simulator
    set_simulator if simulator_id.nil?
    if simulator_id
      Simulator.find(simulator_id)
    else
      nil
    end
  end

  def command
    cmd = simulator.command
    cmd += " #{args}" if args.length > 0
    cmd
  end

  def input
    if simulator.support_input_json
      input = parameter_set.v.dup
      input[:_seed] = seed
      input
    else
      nil
    end
  end

  def args
    if simulator.support_input_json
      ""
    else
      ps = parameter_set
      params = simulator.parameter_definitions.map do |pd|
        ps.v[pd.key]
      end
      params << seed
      params.join(' ')
    end
  end

  def command_and_input
    [command, input]
  end

  def dir
    return ResultDirectory.run_path(self)
  end

  # returns result files and directories
  # directories for Analysis are not included
  def result_paths
    paths = Dir.glob( dir.join('*') ).map {|x|
      Pathname(x)
    }
    # remove directories of Analysis
    paths -= analyses.map {|x| x.dir}

    # return all files and directories on result path (these do not include sub-dirs and files in sub-dirs)
    return paths
  end

  def archived_result_path
    dir.join('..', "#{id}.tar.bz2")
  end

  def destroy
    if status == :submitted or status == :running
      cancel
    elsif status == :cancelled and submitted_to.present?
      cancel
    else
      super
    end
  end

  def enqueue_auto_run_analyzers
    ps = parameter_set
    sim = ps.simulator

    if self.status == :finished
      sim.analyzers.where(type: :on_run, auto_run: :yes).each do |azr|
        anl = analyses.build(analyzer: azr)
        anl.save
      end

      sim.analyzers.where(type: :on_run, auto_run: :first_run_only).each do |azr|
        scope = ps.runs.where(status: :finished)
        if scope.count == 1 and scope.first.id == id
          anl = analyses.build(analyzer: azr)
          anl.save
        end
      end
    end

    if self.status == :finished or self.status == :failed
      sim.analyzers.where(type: :on_parameter_set, auto_run: :yes).each do |azr|
        unless ps.runs.nin(status: [:finished, :failed]).exists?
          anl = ps.analyses.build(analyzer: azr)
          anl.save
        end
      end
    end
  end

  private
  def set_simulator
    if parameter_set
      self.simulator = parameter_set.simulator
    else
      self.simulator = nil
    end
  end

  SeedMax = 2 ** 31
  SeedIterationLimit = 1024
  def set_unique_seed
    unless seed
      SeedIterationLimit.times do |i|
        candidate = rand(SeedMax)
        if self.class.where(:parameter_set_id => parameter_set, :seed => candidate).exists? == false
          self.seed = candidate
          break
        end
      end
      errors.add(:seed, "Failed to set unique seed") unless seed
    end
  end

  def create_run_dir
    FileUtils.mkdir_p(dir)
  end

  def delete_run_dir
    # if self.parameter_set.nil, parent ParameterSet is already destroyed.
    # Therefore, self.dir raises an exception
    if parameter_set and File.directory?(dir)
      FileUtils.rm_r(dir)
    end
  end

  def delete_archived_result_file
    # if self.parameter_set.nil, parent ParameterSet is already destroyed.
    # Therefore, self.archived_result_path raises an exception
    if parameter_set
      archive = archived_result_path
      FileUtils.rm(archive) if File.exist?(archive)
    end
  end

  def remove_runs_status_count_cache
    if parameter_set and parameter_set.reload.runs_status_count_cache
      parameter_set.update_attribute(:runs_status_count_cache, nil)
    end
  end

  def cancel
    self.status = :cancelled
    delete_run_dir
    delete_archived_result_file
    self.parameter_set = nil
    save
  end

  def host_parameters_given
    if submitted_to
      keys = submitted_to.host_parameter_definitions.map {|x| x.key}
      diff = keys - host_parameters.keys
      if diff.any?
        errors.add(:host_parameters, "not given parameters: #{diff.inspect}")
      end
    end
  end

  def host_parameters_format
    if submitted_to
      submitted_to.host_parameter_definitions.each do |host_prm|
        key = host_prm.key
        unless host_parameters[key].to_s =~ Regexp.new(host_prm.format.to_s)
          errors.add(:host_parameters, "#{key} must satisfy #{host_prm.format}")
        end
      end
    end
  end

  def remove_redundant_host_parameters
    if submitted_to
      host_params = submitted_to.host_parameter_definitions.map {|x| x.key}
      host_parameters.select! do |key,val|
        host_params.include?(key)
      end
    end
  end

  def set_job_script
    self.job_script = JobScriptUtil.script_for(self, self.submitted_to)
  end

  def mpi_procs_is_in_range
    if submitted_to
      if mpi_procs.to_i < submitted_to.min_mpi_procs
        errors.add(:mpi_procs, "must be equal to or larger than #{submitted_to.min_mpi_procs}")
      elsif mpi_procs.to_i > submitted_to.max_mpi_procs
        errors.add(:mpi_procs, "must be equal to or smaller than #{submitted_to.max_mpi_procs}")
      end
    end
  end

  def omp_threads_is_in_range
    if submitted_to
      if omp_threads.to_i < submitted_to.min_omp_threads
        errors.add(:omp_threads, "must be equal to or larger than #{submitted_to.min_mpi_procs}")
      elsif omp_threads.to_i > submitted_to.max_omp_threads
        errors.add(:omp_threads, "must be equal to or smaller than #{submitted_to.max_mpi_procs}")
      end
    end
  end
end
