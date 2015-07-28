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
  field :simulator_version, type: String
  field :host_parameters, type: Hash, default: {}
  field :job_id, type: String
  field :job_script, type: String
  field :priority, type: Integer, default: 1
  field :error_messages, type: String
  index({ status: 1 }, { name: "run_status_index" })
  index({ priority: 1 }, { name: "run_priority_index" })
  belongs_to :parameter_set, autosave: false
  belongs_to :simulator, autosave: false  # for caching. do not edit this field explicitly
  has_many :analyses, as: :analyzable, dependent: :destroy
  belongs_to :submitted_to, class_name: "Host"

  PRIORITY_ORDER = {0=>:high, 1=>:normal, 2=>:low}

  # validations
  validates :status, presence: true,
                     inclusion: {in: [:created,:submitted,:running,:failed,:finished, :cancelled]}
  validates :seed, presence: true
  validates :mpi_procs, numericality: {greater_than_or_equal_to: 1, only_integer: true}
  validates :omp_threads, numericality: {greater_than_or_equal_to: 1, only_integer: true}
  validates :priority, presence: true,
                     inclusion: {in: PRIORITY_ORDER.keys}
  validate :host_parameters_given, on: :create
  validate :host_parameters_format, on: :create
  validate :mpi_procs_is_in_range, on: :create
  validate :omp_threads_is_in_range, on: :create
  # validates only for a new_record
  # because Host#max_mpi_procs, max_omp_threads can change during a job is running

  # do not write validations for the presence of association
  # because it can be slow. See http://mongoid.org/en/mongoid/docs/relations.html

  before_create :set_simulator, :remove_redundant_host_parameters, :set_job_script
  before_save :remove_runs_status_count_cache, :if => :status_changed?
  after_create :create_run_dir, :create_job_script_for_manual_submission,
    :update_default_host_parameter_on_its_simulator,
    :update_default_mpi_procs_omp_threads
  before_destroy :delete_run_dir, :delete_archived_result_file ,
                 :delete_files_for_manual_submission, :remove_runs_status_count_cache

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

  def destroy(call_super = false)
    if call_super
      super
    else
      if status == :submitted or status == :running or status == :cancelled
        cancel
      else
        super
      end
    end
  end

  private
  def delete_files_for_manual_submission
    sh_path = ResultDirectory.manual_submission_job_script_path(self)
    FileUtils.rm(sh_path) if sh_path.exist?
    json_path = ResultDirectory.manual_submission_input_json_path(self)
    FileUtils.rm(json_path) if json_path.exist?
    pre_process_script_path = ResultDirectory.manual_submission_pre_process_script_path(self)
    FileUtils.rm(pre_process_script_path) if pre_process_script_path.exist?
    pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(self)
    FileUtils.rm(pre_process_executor_path) if pre_process_executor_path.exist?
  end

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

  def create_job_script_for_manual_submission
    return if submitted_to

    FileUtils.mkdir_p(ResultDirectory.manual_submission_path)
    js_path = ResultDirectory.manual_submission_job_script_path(self)
    File.open(js_path, 'w') {|io| io.puts job_script; io.flush }
    if simulator.support_input_json
      input_json_path = ResultDirectory.manual_submission_input_json_path(self)
      File.open(input_json_path, 'w') {|io| io.puts input.to_json; io.flush }
    end

    if simulator.pre_process_script.present?
      pre_process_script_path = ResultDirectory.manual_submission_pre_process_script_path(self)
      File.open(pre_process_script_path, 'w') {|io| io.puts simulator.pre_process_script.gsub(/\r\n/, "\n"); io.flush } # Since a string taken from DB may contain \r\n, gsub is necessary
      pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(self)
      File.open(pre_process_executor_path, 'w') {|io| io.puts pre_process_executor; io.flush }
      cmd = "cd #{pre_process_executor_path.dirname}; chmod +x #{pre_process_executor_path.basename}"
      system(cmd)
    end
  end

  def update_default_host_parameter_on_its_simulator
    unless self.host_parameters == self.simulator.get_default_host_parameter(self.submitted_to)
      host_id = self.submitted_to.present? ? self.submitted_to.id.to_s : "manual_submission"
      new_host_parameters = self.simulator.default_host_parameters
      new_host_parameters[host_id] = self.host_parameters
      self.simulator.timeless.update_attribute(:default_host_parameters, new_host_parameters)
    end
  end

  def update_default_mpi_procs_omp_threads
    host_id = submitted_to.present? ? submitted_to.id.to_s : "manual_submission"
    unless mpi_procs == simulator.default_mpi_procs[host_id]
      new_default_mpi_procs = simulator.default_mpi_procs
      new_default_mpi_procs[host_id] = mpi_procs
      simulator.timeless.update_attribute(:default_mpi_procs, new_default_mpi_procs)
    end
    unless omp_threads == simulator.default_omp_threads[host_id]
      new_default_omp_threads = simulator.default_omp_threads
      new_default_omp_threads[host_id] = omp_threads
      simulator.timeless.update_attribute(:default_omp_threads, new_default_omp_threads)
    end
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

  def pre_process_executor
    script = <<-EOS
#!/bin/bash
RUN_ID=#{self.id}
mkdir ${RUN_ID}
cp ${RUN_ID}_preprocess.sh ${RUN_ID}/_preprocess.sh
chmod +x ${RUN_ID}/_preprocess.sh
EOS
    if simulator.support_input_json
      script += <<-EOS
if [ -f ${RUN_ID}_input.json ]
then
  cp ${RUN_ID}_input.json ${RUN_ID}/_input.json
else
  echo "${RUN_ID}_input.json is missing"
  exit -1
fi
EOS
    end
    script += <<-EOS
cd ${RUN_ID}
./_preprocess.sh #{self.args}
exit 0
EOS
    return script
  end
end
