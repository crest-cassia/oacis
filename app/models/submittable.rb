module Submittable

  PRIORITY_ORDER = {0=>:high, 1=>:normal, 2=>:low}

  def self.included(base)
    base.send(:field, :status, type: Symbol, default: :created)
    # either :created, :submitted, :running, :failed, :finished, or :cancelled

    # fields which are set when created
    base.send(:belongs_to, :submitted_to, class_name: "Host")
    base.send(:field, :job_script, type: String)
    base.send(:field, :host_parameters, type: Hash, default: {})
    base.send(:field, :mpi_procs, type: Integer, default: 1)
    base.send(:field, :omp_threads, type: Integer, default: 1)
    base.send(:field, :priority, type: Integer, default: 1)

    # fields which are set when submitted
    base.send(:field, :job_id, type: String)
    base.send(:field, :submitted_at, type: DateTime)
    base.send(:field, :error_messages, type: String)

    # fields which are set when included
    base.send(:field, :hostname, type: String)
    base.send(:field, :cpu_time, type: Float)
    base.send(:field, :real_time, type: Float)
    base.send(:field, :started_at, type: DateTime)
    base.send(:field, :finished_at, type: DateTime)
    base.send(:field, :included_at, type: DateTime)
    base.send(:field, :result)  # can be any type. it's up to Simulator spec
    base.send(:field, :simulator_version, type: String)

    # indexes
    base.send(:index, { status: 1 }, { name: "#{base.to_s.downcase}_status_index" })
    base.send(:index, { priority: 1 }, { name: "#{base.to_s.downcase}_priority_index" })

    # validations
    base.send(:validates, :status,
              presence: true,
              inclusion: {in: [:created,:submitted,:running,:failed,:finished, :cancelled]}
              )
    base.send(:validates, :mpi_procs, numericality: {greater_than_or_equal_to: 1, only_integer: true})
    base.send(:validates, :omp_threads, numericality: {greater_than_or_equal_to: 1, only_integer: true})
    base.send(:validates, :priority, presence: true, inclusion: {in: PRIORITY_ORDER.keys})

    base.send(:validate, :host_parameters_given, on: :create)
    base.send(:validate, :host_parameters_format, on: :create)
    base.send(:validate, :mpi_procs_is_in_range, on: :create)
    base.send(:validate, :omp_threads_is_in_range, on: :create)
    # validates only for a new_record
    # because Host#max_mpi_procs, max_omp_threads can change during a job is running

    # callbacks
    base.send(:before_create, :remove_redundant_host_parameters, :set_job_script)
    base.send(:after_create, :create_job_script_for_manual_submission,
                             :update_default_host_parameter_on_its_executable,
                             :update_default_mpi_procs_omp_threads)
    base.send(:before_destroy,
              :delete_files_for_manual_submission)
  end

  def executable
    raise "IMPLEMENT ME"
  end

  def input
    raise "IMPLEMENT ME"
  end

  def args
    raise "IMPLEMENT ME"
  end

  def command_with_args
    cmd = executable.command
    cmd += " #{args}" if args.length > 0
    cmd
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
  # validations
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



  # callbacks
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

  def create_job_script_for_manual_submission
    return if submitted_to

    FileUtils.mkdir_p(ResultDirectory.manual_submission_path)
    js_path = ResultDirectory.manual_submission_job_script_path(self)
    File.open(js_path, 'w') {|io| io.puts job_script; io.flush }
    if executable.support_input_json
      input_json_path = ResultDirectory.manual_submission_input_json_path(self)
      File.open(input_json_path, 'w') {|io| io.puts input.to_json; io.flush }
    end

    if executable.pre_process_script.present?
      pre_process_script_path = ResultDirectory.manual_submission_pre_process_script_path(self)
      File.open(pre_process_script_path, 'w') {|io| io.puts executable.pre_process_script.gsub(/\r\n/, "\n"); io.flush } # Since a string taken from DB may contain \r\n, gsub is necessary
      pre_process_executor_path = ResultDirectory.manual_submission_pre_process_executor_path(self)
      File.open(pre_process_executor_path, 'w') {|io| io.puts pre_process_executor; io.flush }
      cmd = "cd #{pre_process_executor_path.dirname}; chmod +x #{pre_process_executor_path.basename}"
      system(cmd)
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
    if executable.support_input_json
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

  def update_default_host_parameter_on_its_executable
    unless self.host_parameters == self.executable.get_default_host_parameter(self.submitted_to)
      host_id = self.submitted_to.present? ? self.submitted_to.id.to_s : "manual_submission"
      new_host_parameters = self.executable.default_host_parameters
      new_host_parameters[host_id] = self.host_parameters
      self.executable.timeless.update_attribute(:default_host_parameters, new_host_parameters)
    end
  end

  def update_default_mpi_procs_omp_threads
    host_id = submitted_to.present? ? submitted_to.id.to_s : "manual_submission"
    unless mpi_procs == executable.default_mpi_procs[host_id]
      new_default_mpi_procs = executable.default_mpi_procs
      new_default_mpi_procs[host_id] = mpi_procs
      executable.timeless.update_attribute(:default_mpi_procs, new_default_mpi_procs)
    end
    unless omp_threads == executable.default_omp_threads[host_id]
      new_default_omp_threads = executable.default_omp_threads
      new_default_omp_threads[host_id] = omp_threads
      executable.timeless.update_attribute(:default_omp_threads, new_default_omp_threads)
    end
  end

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


  # subroutines of public methods
  def cancel
    self.update_attribute(:status, :cancelled)
  end
end
