class OacisCli < Thor

  desc 'job_parameter_template', "print template of job parameters"
  method_option :host_id,
    type:     :string,
    aliases:  '-h',
    desc:     'id of submitting host',
    required: false
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output json file (run_ids.json)',
    required: true
  def job_parameter_template
    job_parameters = {
      "host_id" => nil,
      "host_parameters" => {},
      "mpi_procs" => 1,
      "omp_threads" => 1,
      "priority" => 1
    }

    if options[:host_id]
      host = Host.find(options[:host_id])
      host_parameters = {}
      host.host_parameter_definitions.each do |param_def|
        host_parameters[param_def.key] = param_def.default
      end
      job_parameters["host_id"] = host.id.to_s
      job_parameters["host_parameters"] = host_parameters
    end

    return if options[:dry_run]
    return unless options[:yes] or overwrite_file?(options[:output])
    File.open(options[:output], 'w') do |io|
      io.puts JSON.pretty_generate(job_parameters)
    end
  end

  desc 'create_runs', "create runs"
  method_option :parameter_sets,
    type:     :string,
    aliases:  '-p',
    desc:     'path to parameter_set_ids.json',
    required: true
  method_option :job_parameters,
    type:     :string,
    aliases:  '-j',
    desc:     'path to job_parameters.json',
    required: true
  method_option :number_of_runs,
    type:     :numeric,
    aliases:  '-n',
    desc:     'runs are created up to this number',
    default:  1
  method_option :seeds,
    type:     :string,
    aliases:  '-s',
    desc:     'runs are created with seeds',
    required: false
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file (run_ids.json)',
    required: true
  def create_runs
    parameter_sets = get_parameter_sets(options[:parameter_sets])
    job_parameters = load_json_file_or_string(options[:job_parameters])
    num_runs = options[:number_of_runs]
    seeds = options[:seeds] ? JSON.parse(options[:seeds]) : []
    submitted_to = job_parameters["host_id"] ? Host.find(job_parameters["host_id"]) : nil
    host_parameters = job_parameters["host_parameters"].to_hash
    mpi_procs = job_parameters["mpi_procs"]
    omp_threads = job_parameters["omp_threads"]
    priority = job_parameters["priority"]

    run_ids = create_runs_impl(parameter_sets, num_runs, submitted_to, host_parameters, mpi_procs, omp_threads, priority, seeds)

  ensure
    return if options[:dry_run]
    return unless options[:yes] or overwrite_file?(options[:output])
    write_run_ids_to_file(options[:output], run_ids)
  end

  private
  def create_runs_impl(parameter_sets, num_runs, submitted_to, host_parameters, mpi_procs, omp_threads, priority, seeds)
    progressbar = ProgressBar.create(total: parameter_sets.size, format: "%t %B %p%% (%c/%C)")
    if options[:verbose]
      progressbar.log "Number of parameter_sets : #{parameter_sets.count}"
    end

    run_ids = []
    list_runs = {}
    Run.collection.aggregate(
      { '$match' => {'parameter_set_id' => {'$in'=>parameter_sets.map(&:id)}} },
      { '$group' => {'_id' => '$parameter_set_id', run_ids: {'$push' => '$_id'}} }
    ).each do |ps_runs|
      list_runs[ps_runs['_id']] = ps_runs['run_ids']
    end
    parameter_sets.map(&:id).each do |ps_id|
      if list_runs[ps_id] and list_runs[ps_id].size >= num_runs
        run_ids += list_runs[ps_id][0..(num_runs-1)]
        progressbar.increment
        next
      end
      existing_run_ids = list_runs[ps_id] || []
      run_ids += existing_run_ids
      ps = ParameterSet.find(ps_id)
      sim = ps.simulator
      mpi_procs = sim.support_mpi ? mpi_procs : 1
      omp_threads = sim.support_omp ? omp_threads : 1
      (num_runs - existing_run_ids.count).times do |i|
        run = ps.runs.build(submitted_to: submitted_to,
                            mpi_procs: mpi_procs,
                            omp_threads: omp_threads,
                            host_parameters: host_parameters,
                            priority: priority)
        run.seed = seeds[i] if seeds[i]
        if run.valid?
          run.save! unless options[:dry_run]
          run_ids << run.id
        else
          progressbar.log "Failed to create a Run for ParameterSet #{ps.id}"
          progressbar.log run.errors.full_messages
          raise "failed to create a Run"
        end
      end
      progressbar.increment
    end
    run_ids
  end

  private
  def write_run_ids_to_file(path, run_ids)
    return unless run_ids.present?
    ids = run_ids.map {|run_id| "  #{{'run_id' => run_id.to_s}.to_json}"}
    File.open(path, 'w') {|io|
      io.puts "[", ids.join(",\n"), "]"
      io.flush
    }
  end

  public
  desc 'run_status', "print run status"
  method_option :run_ids,
    type:     :string,
    aliases:  '-r',
    desc:     'target runs',
    required: true
  def run_status
    runs = get_runs(options[:run_ids])
    counts = {total: runs.count}
    [:created,:submitted,:running,:failed,:finished].each do |status|
      counts[status] = runs.where(status: status).count
    end
    $stdout.puts JSON.pretty_generate(counts)
  end

  desc 'destroy_runs', "destroy runs"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of run specified as Hash (e.g. --query=status:failed simulator_version=0.0.1)',
    required: true
  def destroy_runs
    sim = get_simulator(options[:simulator])
    runs = find_runs(sim, options[:query])

    if runs.empty?
      say("No runs are found.")
      return
    end

    if options[:verbose]
      say("Found runs: #{runs.map(&:id).to_json}")
    end

    if options[:yes] or yes?("Destroy #{runs.count} runs?")
      progressbar = ProgressBar.create(total: runs.count, format: "%t %B %p%% (%c/%C)")
      # no_timeout enables destruction of 10000 or more runs
      runs.no_timeout.each do |run|
        run.update_attribute(:to_be_destroyed, true)
        run.set_lower_submittable_to_be_destroyed
        progressbar.increment
      end
    end
  end

  desc 'replace_runs', "replace runs"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
  method_option :query,
    type:     :hash,
    aliases:  '-q',
    desc:     'query of run specified as Hash (e.g. --query=status:failed simulator_version=0.0.1)',
    required: true
  def replace_runs
    sim = get_simulator(options[:simulator])
    runs = find_runs(sim, options[:query])

    if runs.empty?
      say("No runs are found.")
      return
    end

    if options[:verbose]
      say("Found runs: #{runs.map(&:id).to_json}")
    end

    if options[:yes] or yes?("Replace #{runs.count} runs with new ones?")
      progressbar = ProgressBar.create(total: runs.count, format: "%t %B %p%% (%c/%C)")
      run_ids = runs.only(:id).map(&:id)
      run_ids.each do |runid|
        run = Run.find(runid)
        run_attr = { submitted_to: run.submitted_to,
                     mpi_procs: run.mpi_procs,
                     omp_threads: run.omp_threads,
                     host_parameters: run.host_parameters,
                     priority: run.priority }
        new_run = run.parameter_set.runs.build(run_attr)
        if new_run.save
          run.update_attribute(:to_be_destroyed, true)
          run.set_lower_submittable_to_be_destroyed
        else
          progressbar.log "Failed to create Run #{new_run.errors.full_messages}"
        end
        progressbar.increment
      end
    end
  end

  private
  def find_runs(simulator, query)
    unless query["status"] or query["simulator_version"]
      say("query must have 'status' or 'simulator_version' key", :red)
      raise "invalid query"
    end
    runs = Run.where(simulator: simulator)
    if stat = query["status"]
      runs = runs.where(status: stat.to_sym)
    end
    if version = query["simulator_version"]
      version = nil if version == ""
      runs = runs.where(simulator_version: version)
    end
    runs
  end
end
