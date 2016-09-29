class Run
  include Mongoid::Document
  include Mongoid::Timestamps

  include Submittable

  field :seed, type: Integer

  belongs_to :parameter_set, autosave: false
  belongs_to :simulator, autosave: false  # for caching. do not edit this field explicitly
  has_many :analyses, as: :analyzable

  default_scope ->{ where(:to_be_destroyed.in => [nil,false]) }
  index({updatd_at: -1, status: -1}, { name: "run_table_default_order_index" })

  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  before_create :set_unique_seed, :set_simulator
  before_save :remove_runs_status_count_cache, :if => Proc.new {|run| run.status_changed? or run.to_be_destroyed_changed? }
  after_create :create_run_dir
  before_destroy :delete_run_dir, :delete_archived_result_file,
                 :remove_runs_status_count_cache

  public
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
  #   sub-directories and files in them are not included
  # directories for Analysis are not included
  def result_paths( pattern = '*' )
    paths = nil
    Dir.chdir(dir) {
      paths = Dir.glob(pattern).map {|x| Pathname.new(x).expand_path }
    }
    # remove directories of Analysis
    anl_dirs = analyses.map {|anl| /^#{anl.dir.to_s}/ }
    paths.reject do |path|
      anl_dirs.find {|anl_dir| anl_dir =~ path.to_s }
    end
  end

  def archived_result_path
    dir.join('..', "#{id}.tar.bz2")
  end

  def discard
    update_attribute(:to_be_destroyed, true)
    set_lower_submittable_to_be_destroyed
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
      if simulator.sequential_seed
        seeds = parameter_set.reload.runs.asc(:seed).only(:seed).map {|r| r.seed }
        found = seeds.each_with_index.find {|seed,idx| seed != idx + 1 }
        next_seed = found ? found[1] + 1 : seeds.last.to_i + 1
        self.seed = next_seed
      else
        counter_epoch = self.id.to_s[-6..-1] + self.id.to_s[0..7]
        self.seed = counter_epoch.hex % (2**31-1)
      end
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
