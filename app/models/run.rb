class Run
  include Mongoid::Document
  include Mongoid::Timestamps
  field :status, type: Symbol  # created, running, including failed, canceled, finished
  field :seed, type: Integer
  field :hostname, type: String
  field :cpu_time, type: Float
  field :real_time, type: Float
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :included_at, type: DateTime
  field :result  # can be any type. it's up to Simulator spec
  belongs_to :parameter_set
  embeds_many :analysis_runs, as: :analyzable

  # validations
  validates :status, :presence => true
  validates :seed, :presence => true, :uniqueness => true
  validates :parameter_set, :presence => true

  attr_accessible :seed

  before_validation :set_status, :set_unique_seed
  after_save :create_run_dir

  public
  def simulator
    parameter_set.simulator
  end
  
  def submit
    run_info = {id: id, command: command, dir: dir.to_s}
    Resque.enqueue(SimulatorRunner, run_info)
  end

  def command
    prm = self.parameter_set
    sim = prm.simulator
    cmd_array = []
    cmd_array << sim.command
    cmd_array += sim.parameter_definitions.keys.map do |key|
      prm.v[key]
    end
    cmd_array << self.seed
    return cmd_array.join(' ')
  end

  def dir
    return ResultDirectory.run_path(self)
  end

  # returns result files and directories
  # directories for AnalysisRuns are not included
  def result_paths
    paths = Dir.glob( dir.join('*') ).map {|x|
      Pathname(x)
    }
    # remove directories of AnalysisRuns
    paths -= analysis_runs.map {|x| x.dir}
    return paths
  end

  def set_status_running( option = {hostname: 'localhost'} )
    self.status = :running
    self.hostname = option[:hostname]
    self.started_at = DateTime.now
    self.save
  end

  def set_status_finished(option = {cpu_time: 0.0, real_time: 0.0})
    merged = {cpu_time: 0.0, real_time: 0.0}.merge(option)
    self.status = :finished
    self.cpu_time = merged[:cpu_time]
    self.real_time = merged[:real_time]
    self.result = merged[:result]
    self.finished_at = DateTime.now
    self.included_at = DateTime.now
    self.save
  end

  def set_status_failed
    self.status = :failed
    self.save
  end

  private
  def set_status
    self.status ||= :created
  end

  SeedMax = 2 ** 31
  SeedIterationLimit = 1024
  def set_unique_seed
    unless self.seed
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
    FileUtils.mkdir_p(ResultDirectory.run_path(self))
  end
end
