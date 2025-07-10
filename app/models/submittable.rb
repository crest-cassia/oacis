module Submittable

  PRIORITY_ORDER = {0=>:high, 1=>:normal, 2=>:low}

  def self.included(base)
    base.send(:field, :status, type: Symbol, default: :created)
    # either :created, :submitted, :running, :failed, or :finished
    base.send(:field, :to_be_destroyed, type: Boolean, default: false)

    # fields which are set when created
    base.send(:belongs_to, :submitted_to, class_name: "Host")
    base.send(:belongs_to, :host_group)
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
    version_field = base == Run ? :simulator_version : :analyzer_version
    base.send(:field, version_field, type: String)

    # indexes
    base.send(:index, { status: 1, submitted_to_id: 1 }, { name: "#{base.to_s.downcase}_status_submitted_to_index" })
    base.send(:index, { status: 1, created_at: -1 }, { name: "#{base.to_s.downcase}_status_updated_at_index" })

    # validations
    base.send(:validates, :status,
              presence: true,
              inclusion: {in: [:created,:submitted,:running,:failed,:finished]}
              )
    base.send(:validates, :mpi_procs, numericality: {greater_than_or_equal_to: 1, only_integer: true})
    base.send(:validates, :omp_threads, numericality: {greater_than_or_equal_to: 1, only_integer: true})
    base.send(:validates, :priority, presence: true, inclusion: {in: PRIORITY_ORDER.keys})

    base.send(:validate, :submitted_to_or_host_group_given, on: :create)
    base.send(:validate, :host_parameters_given, on: :create)
    base.send(:validate, :host_parameters_format, on: :create)
    base.send(:validate, :mpi_procs_is_in_range, on: :create)
    base.send(:validate, :omp_threads_is_in_range, on: :create)
    # validates only for a new_record
    # because Host#max_mpi_procs, max_omp_threads can change during a job is running

    # callbacks
    base.send(:before_create, :remove_redundant_host_parameters)
    base.send(:after_create, :set_job_script,
                             # set_job_script must be called at after_create
                             # since seed is set at before_create callback
                             :update_default_host_parameter_on_its_executable,
                             :update_default_mpi_procs_omp_threads)

    base.send(:scope, :unfinished, -> { where(:status.in => %i[created submitted running]) })
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

  def version
    self.is_a?(Run) ? simulator_version : analyzer_version
  end

  def version=(arg)
    self.is_a?(Run) ? self.simulator_version=arg : self.analyzer_version=arg
  end

  def command_with_args
    cmd = executable.command
    cmd += " #{args}" if args.length > 0
    cmd
  end

  private
  # validations
  def submitted_to_or_host_group_given
    if submitted_to.nil? and host_group.nil?
      errors.add(:submitted_to, "destination must be specified")
    end
  end

  def host_parameters_given
    if submitted_to
      keys = submitted_to.host_parameter_definitions.map {|x| x.key}
      diff = keys - host_parameters.keys.map(&:to_s)
      if diff.any?
        errors.add(:host_parameters, "not given parameters: #{diff.inspect}")
      end
    end
  end

  def host_parameters_format
    if submitted_to
      submitted_to.host_parameter_definitions.each do |host_prm|
        key = host_prm.key
        regexp = Regexp.new(host_prm.format.to_s)
        unless host_parameters.with_indifferent_access[key].to_s =~ regexp
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
        errors.add(:omp_threads, "must be equal to or larger than #{submitted_to.min_omp_threads}")
      elsif omp_threads.to_i > submitted_to.max_omp_threads
        errors.add(:omp_threads, "must be equal to or smaller than #{submitted_to.max_omp_threads}")
      end
    end
  end



  # callbacks
  def remove_redundant_host_parameters
    if submitted_to
      host_params = submitted_to.host_parameter_definitions.map {|x| x.key}
      self.host_parameters = host_parameters.map {|k,v| [k.to_s,v] }
        .select{|k,v| host_params.include?(k) }
        .to_h
    end
  end

  def set_job_script
    self.update_attribute(:job_script, JobScriptUtil.script_for(self))
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
    return if submitted_to.nil?
    unless self.host_parameters == self.executable.get_default_host_parameter(self.submitted_to)
      host_id = self.submitted_to.id.to_s
      new_host_parameters = self.executable.default_host_parameters
      new_host_parameters[host_id] = self.host_parameters
      self.executable.timeless.update_attribute(:default_host_parameters, new_host_parameters)
    end
  end

  def update_default_mpi_procs_omp_threads
    host_id = submitted_to.present? ? submitted_to.id.to_s : self.host_group.id.to_s
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
end
