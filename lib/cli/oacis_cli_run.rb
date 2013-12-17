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
    desc:     'target parameter_sets',
    required: true
  method_option :number_of_runs,
    type:     :numeric,
    aliases:  '-n',
    desc:     'runs are created up to this number',
    default:  1
  method_option :host_parameters,
    type:     :string,
    aliases:  '-h',
    desc:     'json file of host parameters',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def create_runs
    puts MESSAGE["greeting"] if options[:verbose]
    stdin = STDIN
    data = JSON.load(stdin)
    unless data
      $stderr.puts "ERROR:data is not json format"
      exit(-1)
    end
    ps = get_parameter_sets(options[:parameter_sets])
    host = get_host(options[:host]).first
    if options[:verbose]
      puts "data = "
      puts JSON.pretty_generate(data)
    end

    if create_runs_data_is_valid?(data, ps, host)
      puts  "data is valid" if options[:verbose]
    else
      puts  "data is not valid" if options[:verbose]
      exit(-1)
    end

    unless options[:dry_run]
      create_runs_do(data, ps, host)
    end
  end
end