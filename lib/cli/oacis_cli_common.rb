class OacisCli < Thor

  class_option :dry_run, type: :boolean, aliases: '-d', desc: 'dry run'
  class_option :verbose, type: :boolean, aliases: '-v', desc: 'verbose mode'

  USAGE = <<"EOS"
usage:
#1 make host.json file
  oacis_cli.rb show_host -o host.json
  #check or edit host.json
#2 create simulator
  oacis_cli create_simulator -h host.json -i simulator.json -o simulator_id.json
  #you can get simulator.json template file "oacis_cli simulator_template -o simulator.json"
  #edit simulator.json (at least following fields, "name", "command", "parameter_definitions")
#3 create parameter_set
  oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json
  #you can get parameter_sets.json template file "oacis_cli parameter_sets_template -s simulator_id.json -o parameter_sets.json"
#4 create job parameter template
  oacis_cli job_parameter_template -h host_id -o job_parameters.json
#5 edit job_parameters.json. Then create run
  oacis_cli create_runs -p parameter_set_ids.json -j job_parameters.json -n 1 -o run_ids.json
#6 check run status
  oacis_cli run_status -r run_ids.json
EOS

  desc 'usage', "print usage"
  def usage
    puts USAGE
  end

  desc 'show_host', "show_host"
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def show_host
    hosts = Host.all.map do |host|
      {id: host.id.to_s, name: host.name, hostname: host.hostname, user: host.user}
    end
    return if options[:dry_run]
    File.open(options[:output], 'w') {|io|
      io.puts JSON.pretty_generate(hosts)
      io.flush
    }
  end

  private
  def get_host(file)
    if File.exist?(file)
      io = File.open(file,"r")
      parsed = JSON.load(io)
      host_ids=parsed.map {|h| h["id"]}
    else
      $stderr.puts "host file '#{file}' is not exist"
      exit(-1)
    end
    host=[]
    host_ids.each do |host_id|
      if host_id
        host.push Host.find(host_id)
      else
        $stderr.puts "host_id is not existed"
        exit(-1)
      end
    end
    host
  end

  def get_simulator(file)
    parsed = JSON.load( File.read(file) )
    validate_simulator_id(parsed)
    Simulator.find(parsed["simulator_id"])
  end

  def validate_simulator_id(parsed)
    unless parsed.is_a?(Hash) and parsed.has_key?("simulator_id")
      raise "Invalid json format. Must be a Hash having 'simulator_id' key."
    end
  end

  def get_parameter_sets(file)
    parsed = JSON.load( File.read(file) )
    validate_parameter_set_ids(parsed)
    parsed.map {|h| ParameterSet.find( h["parameter_set_id"] ) }
  end

  def validate_parameter_set_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("parameter_set_id") }
      raise "Invalid json format. Key 'parameter_set_id' is necessary."
    end
  end

  def get_runs(file)
    parsed = JSON.load( File.read(file) )
    validate_run_ids(parsed)
    parsed.map {|h| Run.find(h["run_id"]) }
  end

  def validate_run_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("run_id") }
      raise "Invalid json format. Key 'run_id' is necessary."
    end
  end
end
