class Run
  include Mongoid::Document
  include Mongoid::Timestamps
  field :status, type: Symbol, default: :created  # created, submitted, running, failed, finished
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
  has_many :analyses, as: :analyzable
  belongs_to :submitted_to, class_name: "Host"
  has_and_belongs_to_many :submittable_hosts, class_name: "Host", inverse_of: nil

  # validations
  validates :status, presence: true,
                     inclusion: {in: [:created,:submitted,:running,:failed,:finished]}
  validates :seed, presence: true, uniqueness: {scope: :parameter_set_id}
  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  attr_accessible :seed
  before_validation :set_submittable_hosts

  after_save :create_run_dir

  public
  def initialize(*arg)
    super
    set_unique_seed
  end

  def simulator
    parameter_set.simulator
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
      cmd_array += sim.parameter_definitions.keys.map do |key|
        prm.v[key]
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
    return paths
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

  SeedMax = 2 ** 31
  SeedIterationLimit = 1024
  private
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

  def set_submittable_hosts
    if self.submittable_hosts.empty?
      self.submittable_hosts = self.simulator.executable_on
    end
  end
end
