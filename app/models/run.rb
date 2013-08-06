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
  belongs_to :parameter_set
  belongs_to :simulator  # for caching. do not edit this field explicitly
  has_many :analyses, as: :analyzable, dependent: :destroy
  belongs_to :submitted_to, class_name: "Host"

  # validations
  validates :status, presence: true,
                     inclusion: {in: [:created,:submitted,:running,:failed,:finished, :cancelled]}
  validates :seed, presence: true, uniqueness: {scope: :parameter_set_id}
  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  attr_accessible :seed

  before_save :set_simulator
  after_create :create_run_dir
  before_destroy :delete_run_dir, :delete_archived_result_file

  public
  def initialize(*arg)
    super
    set_unique_seed
  end

  def command
    command_and_input[0]
  end

  def command_and_input
    prm = self.parameter_set
    sim = prm.simulator
    cmd_array = []
    cmd_array << sim.command
    input = nil
    if sim.support_input_json
      input = prm.v.dup
      input[:_seed] = self.seed
    else
      cmd_array += sim.parameter_definitions.map do |pd|
        prm.v[pd.key]
      end
      cmd_array << self.seed
    end
    return cmd_array.join(' '), input
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

    # traverse sub-directories only for one-level depth
    paths.map! do |path|
      unless File.directory?(path)
        path
      end
    end
    return paths.flatten.compact
  end

  def archived_result_path
    dir.join('..', "#{self.id}.tar.bz2")
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
    ps = self.parameter_set
    sim = ps.simulator

    if self.status == :finished
      sim.analyzers.where(type: :on_run, auto_run: :yes).each do |azr|
        anl = self.analyses.build(analyzer: azr)
        anl.save and anl.submit
      end

      sim.analyzers.where(type: :on_run, auto_run: :first_run_only).each do |azr|
        scope = ps.runs.where(status: :finished)
        if scope.count == 1 and scope.first.id == self.id
          anl = self.analyses.build(analyzer: azr)
          anl.save and anl.submit
        end
      end
    end

    if self.status == :finished or self.status == :failed
      sim.analyzers.where(type: :on_parameter_set, auto_run: :yes).each do |azr|
        unless ps.runs.nin(status: [:finished, :failed]).exists?
          anl = ps.analyses.build(analyzer: azr)
          anl.save and anl.submit
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
    FileUtils.mkdir_p(self.dir)
  end

  def delete_run_dir
    # if self.parameter_set.nil, parent ParameterSet is already destroyed.
    # Therefore, self.dir raises an exception
    if self.parameter_set and File.directory?(self.dir)
      FileUtils.rm_r(self.dir)
    end
  end

  def delete_archived_result_file
    # if self.parameter_set.nil, parent ParameterSet is already destroyed.
    # Therefore, self.archived_result_path raises an exception
    if self.parameter_set
      archive = archived_result_path
      FileUtils.rm(archive) if File.exist?(archive)
    end
  end

  def cancel
    self.status = :cancelled
    delete_run_dir
    delete_archived_result_file
    self.parameter_set = nil
    self.save
  end
end
