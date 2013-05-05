class AnalysisRun
  include Mongoid::Document
  include Mongoid::Timestamps

  field :parameters, type: Hash
  field :status, type: Symbol
  field :hostname, type: String
  field :cpu_time, type: Float
  field :real_time, type: Float
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :included_at, type: DateTime
  field :result

  belongs_to :analyzer
  def analyzer  # find embedded document
    unless @analyzer_cache
      if analyzer_id and analyzable
        @analyzer_cache = analyzable.simulator.analyzers.find(analyzer_id)
      end
    end
    return @analyzer_cache
  end
  embedded_in :analyzable, polymorphic: true

  before_validation :set_status
  validates :status, presence: true,
                     inclusion: {in: [:created,:running,:including,:failed,:canceled,:finished]}
  validates :analyzable, :presence => true
  validates :analyzer, :presence => true
  validate :cast_and_validate_parameter_values

  after_save :create_dir

  attr_accessible :parameters, :analyzer

  public
  def dir
    ResultDirectory.analysis_run_path(self)
  end

  def submit
    Resque.enqueue(AnalyzerRunner, analyzer.type, analyzable.to_param, self.to_param)
  end

  def update_status_running(option = {hostname: 'localhost'})
    merged = {hostname: 'localhost'}.merge(option)
    self.status = :running
    self.hostname = option[:hostname]
    self.started_at = DateTime.now
    self.save
  end

  def update_status_including(option = {cpu_time: 0.0, real_time: 0.0})
    merged = {cpu_time: 0.0, real_time: 0.0}.merge(option)
    self.status = :including
    self.cpu_time = merged[:cpu_time]
    self.real_time = merged[:real_time]
    self.result = merged[:result]
    self.finished_at = DateTime.now
    self.save
  end

  def update_status_finished
    self.status = :finished
    self.included_at = DateTime.now
    self.save
  end

  # returns an hash object which is going to be dumped into _input.json
  def input
    obj = {}
    obj[:analysis_parameters] = self.parameters
    case self.analyzer.type
    when :on_run
      run = self.analyzable
      obj[:simulation_parameters] = run.parameter_set.v
      obj[:result] = run.result
    else
      raise "not supported type"
    end
    return obj
  end

  # returns an array of aboslute pathnames of files to be copied to _input/
  def input_files
    files = []
    case self.analyzer.type
    when :on_run
      run = self.analyzable
      files = run.result_paths
      # TODO: add directories of dependent analysis
    else
      raise "not supported type"
    end
    return files
  end

  private
  def set_status
    self.status ||= :created
  end

  def cast_and_validate_parameter_values
    unless parameters.is_a?(Hash)
      errors.add(:parameters, "parameters is not a Hash")
      return
    end

    return unless analyzer
    defn = analyzer.parameter_definitions
    casted = ParametersUtil.cast_parameter_values(parameters, defn, errors)
    if casted.nil?
      errors.add(:parameters, "parameters are invalid. See the definition.")
      return
    end
    self.parameters = casted
  end

  def create_dir
    FileUtils.mkdir_p(self.dir)
  end
end
