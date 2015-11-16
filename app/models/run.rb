class Run
  include Mongoid::Document
  include Mongoid::Timestamps

  include Submittable

  field :seed, type: Integer

  belongs_to :parameter_set, autosave: false
  belongs_to :simulator, autosave: false  # for caching. do not edit this field explicitly
  has_many :analyses, as: :analyzable

  default_scope ->{ where(:to_be_destroyed.in => [nil,false]) }

  # validations
  validates :seed, presence: true

  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  before_create :set_simulator
  before_save :remove_runs_status_count_cache, :if => Proc.new {|run| run.status_changed? or run.to_be_destroyed_changed? }
  after_create :create_run_dir
  before_destroy :delete_run_dir, :delete_archived_result_file,
                 :remove_runs_status_count_cache

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

  def executable
    simulator
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

  def destroyable?
    analyses.unscoped.empty?
  end

  def set_lower_submittable_to_be_destroyed
    analyses.update_all(to_be_destroyed: true)
  end

  private
  def set_simulator
    if parameter_set
      self.simulator = parameter_set.simulator
    else
      self.simulator = nil
    end
  end

  def set_unique_seed
    unless seed
      counter_epoch = self.id.to_s[-6..-1] + self.id.to_s[0..7]
      self.seed = counter_epoch.hex % (2**31-1)
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
end
