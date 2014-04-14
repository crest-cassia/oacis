class Analysis
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
  field :analyzer_version, type: String
  index({ status: 1 }, { name: "analysis_status_index" })

  belongs_to :analyzer
  belongs_to :analyzable, polymorphic: true, autosave: false
  belongs_to :parameter_set

  before_validation :set_status
  validates :status, presence: true,
                     inclusion: {in: [:created,:running,:failed,:cancelled,:finished]}
  validates :analyzer, :presence => true
  validate :cast_and_validate_parameter_values

  before_create :assign_parameter_set_id
  after_create :create_dir
  before_destroy :delete_dir

  attr_accessible :parameters, :analyzer

  public
  def dir
    ResultDirectory.analysis_path(self)
  end

  # returns result files and directories
  def result_paths
    paths = Dir.glob( dir.join('*') ).map {|x|
      Pathname(x)
    }
    return paths
  end

  def destroy( called_by_worker = false )
    s = self.status
    if s == :failed or s == :finished or called_by_worker
      super
    else
      cancel
    end
  end

  def update_status_running(option = {hostname: 'localhost'})
    merged = {hostname: 'localhost'}.merge(option)
    self.status = :running
    self.hostname = option[:hostname]
    self.started_at = DateTime.now
    self.save
  end

  def update_status_finished(status)
    self.cpu_time = status[:cpu_time]
    self.real_time = status[:real_time]
    self.result = status[:result] if status.has_key?(:result)
    self.finished_at = status[:finished_at]
    self.status = :finished
    self.analyzer_version = status[:analyzer_version] if status.has_key?(:version)
    self.included_at = DateTime.now
    self.save
  end

  def update_status_failed
    self.status = :failed
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
    when :on_parameter_set
      ps = self.analyzable
      obj[:simulation_parameters] = ps.v
      obj[:result] = {}
      ps.runs.each do |run|
        obj[:result][run.to_param] = run.result
      end
    else
      raise "not supported type"
    end
    return obj
  end

  # returns a hash
  #   key: relative path of the destination directory from _input/
  #   value: array of aboslute pathnames of files to be copied to _input/
  def input_files
    files = {}
    case self.analyzer.type
    when :on_run
      run = self.analyzable
      files['.'] = run.result_paths
      # TODO: add directories of dependent analysis
    when :on_parameter_set
      ps = self.analyzable
      ps.runs.where(status: :finished).each do |finished_run|
        files[finished_run.to_param] = finished_run.result_paths
      end
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
    return unless analyzer
    defn = analyzer.parameter_definitions
    casted = ParametersUtil.cast_parameter_values(parameters, defn, errors)
    if casted.nil?
      errors.add(:parameters, "parameters are invalid. See the definition.")
      return
    end
    self.parameters = casted
  end

  def assign_parameter_set_id
    if analyzable.is_a?(Run)
      self.parameter_set = analyzable.parameter_set
    elsif analyzable.is_a?(ParameterSet)
      self.parameter_set = analyzable
    else
      raise "must not happen"
    end
  end

  def create_dir
    FileUtils.mkdir_p(self.dir)
  end

  def delete_dir
    # if self.analyzable_id.nil, parent Analyzable item is already destroyed.
    # Therefore, self.dir raises an exception
    if self.analyzable && !self.analyzable.destroyed? && File.directory?(self.dir)
      FileUtils.rm_r(self.dir)
    end
  end

  def cancel
    delete_dir
    self.status = :cancelled
    self.analyzable_id = nil
    self.save
  end
end
