class OacisCli < Thor

  desc 'job_parameter_template', "print template of job parameters"
  method_option :host_id,
    type:     :string,
    aliases:  '-h',
    desc:     'id of submitting host',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output json file (run_ids.json)',
    required: true
  def job_parameter_template
    host = Host.find(options[:host_id])
    host_parameters = {}
    host.host_parameter_definitions.each do |param_def|
      host_parameters[param_def.key] = param_def.default
    end

    File.open(options[:output], 'w') do |io|
      job_parameters = {
        "host_id" => host.id.to_s,
        "host_parameters" => host_parameters,
        "mpi_procs" => 1,
        "omp_threads" => 1
      }
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
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file (run_ids.json)',
    required: true
  def create_runs
    parameter_sets = get_parameter_sets(options[:parameter_sets])
    job_parameters = JSON.load( File.read(options[:job_parameters]) )
    submitted_to = Host.find(job_parameters["host_id"])
    host_parameters = job_parameters["host_parameters"].to_hash

    if options[:verbose]
      $stderr.puts "Number of parameter_sets : #{parameter_sets.count}"
    end

    runs = []
    parameter_sets.each_with_index.map do |ps, idx|
      $stderr.puts "Creating Runs : #{idx} / #{parameter_sets.count}"
      sim = ps.simulator
      mpi_procs = sim.support_mpi ? job_parameters["mpi_procs"] : 1
      omp_threads = sim.support_omp ? job_parameters["omp_threads"] : 1
      existing_runs = ps.runs.limit(options[:number_of_runs]).to_a
      runs += existing_runs
      (options[:number_of_runs] - existing_runs.count).times do |i|
        run = ps.runs.build(submitted_to: submitted_to,
                            mpi_procs: mpi_procs,
                            omp_threads: omp_threads,
                            host_parameters: host_parameters)
        if run.valid?
          run.save! unless options[:dry_run]
          runs << run
        else
          $stderr.puts "Failed to create a Run for ParameterSet #{ps.id}"
          $stderr.puts run.errors.full_messages
          write_run_ids_to_file(options[:output], runs) unless options[:dry_run]
          raise "failed to create a Run"
        end
      end
    end

    write_run_ids_to_file(options[:output], runs) unless options[:dry_run]
  end

  private
  def write_run_ids_to_file(path, runs)
    return unless runs.present?
    File.open(path, 'w') {|io|
      ids = runs.map {|run| "  #{{'run_id' => run.id.to_s}.to_json}"}
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
      counts[status] = runs.count {|run| run.status == status}
    end
    $stdout.puts JSON.pretty_generate(counts)
  end
end
