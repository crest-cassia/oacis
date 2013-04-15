class Run
  include Mongoid::Document
  include Mongoid::Timestamps
  field :status, type: Symbol  # created, running, failed, canceled, finished
  field :seed, type: Integer
  field :hostname, type: String
  field :cpu_time, type: Float
  field :real_time, type: Float
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :included_at, type: DateTime
  belongs_to :parameter
  # belongs_to :job

  # validations
  validates :status, :presence => true
  validates :seed, :presence => true, :uniqueness => true
  validates :parameter, :presence => true

  attr_accessible :seed

  before_validation :set_status, :set_unique_seed
  after_save :create_run_dir

  public
  def submit
    Resque.enqueue(SimulatorRunner, self.id)
  end

  def command
    prm = self.parameter
    sim = parameter.simulator
    cmd_array = []
    cmd_array << sim.execution_command
    cmd_array += sim.parameter_keys.keys.map do |key|
      prm.sim_parameters[key]
    end
    cmd_array << self.seed
    return cmd_array.join(' ')
  end

  def dir
    return ResultDirectory.run_path(self)
  end

  def set_status_running( option = {hostname: 'localhost'} )
    self.status = :running
    self.hostname = option[:hostname]
    self.started_at = DateTime.now
    self.save
  end

  def set_status_finished( option = {cpu_time: 0.0, real_time: 0.0} )
    self.status = :finished
    self.cpu_time = option[:cpu_time]
    self.real_time = option[:real_time]
    self.finished_at = DateTime.now
    self.included_at = DateTime.now
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
        if self.class.where(:parameter_id => parameter, :seed => candidate).exists? == false
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
