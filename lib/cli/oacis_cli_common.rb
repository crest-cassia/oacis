class OacisCli < Thor

  class_option :dry_run, type: :boolean, aliases: '-d', desc: 'dry run'
  class_option :verbose, type: :boolean, aliases: '-v', desc: 'verbose mode'
  class_option :yes, type: :boolean, aliases: '-y', desc: 'say "yes" for all questions'

  USAGE = <<"EOS"
usage:
#1 make host.json file
  ./bin/oacis_cli show_host -o host.json
  #check or edit host.json
#2 create simulator
  ./bin/oacis_cli create_simulator -h host.json -i simulator.json -o simulator_id.json
  #you can get simulator.json template file "./bin/oacis_cli simulator_template -o simulator.json"
  #edit simulator.json (at least following fields, "name", "command", "parameter_definitions")
#3 create parameter_set
  ./bin/oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json
  #you can get parameter_sets.json template file "./bin/oacis_cli parameter_sets_template -s simulator_id.json -o parameter_sets.json"
#4 create job parameter template
  ./bin/oacis_cli job_parameter_template -h ${host_id} -o job_parameter.json
#5 edit job_parameters.json. Then create run
  ./bin/oacis_cli create_runs -p parameter_set_ids.json -j job_parameter.json -n 1 -o run_ids.json
#6 check run status
  ./bin/oacis_cli run_status -r run_ids.json
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

  def get_simulator(simulator_id)
    if simulator_id =~ /[0-9a-f]{24}/
      return Simulator.find(simulator_id)
    else
      parsed = JSON.load( File.read(simulator_id) )
      validate_simulator_id(parsed)
      return Simulator.find(parsed["simulator_id"])
    end
  end

  def validate_simulator_id(parsed)
    unless parsed.is_a?(Hash) and parsed.has_key?("simulator_id")
      raise "Invalid json format. Must be a Hash having 'simulator_id' key."
    end
  end

  def get_parameter_sets(file)
    parsed = JSON.load( File.read(file) )
    validate_parameter_set_ids(parsed)
    parameter_sets = ParameterSet.in(id: parsed.map {|h| h["parameter_set_id"] } )
    raise "Invalid #{parsed.length - parameter_sets.count} prameter_set_ids are found" if parameter_sets.count != parsed.length
    parameter_sets
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
    runs = Run.in(id: parsed.map {|h| h["run_id"] } )
    raise "Invalid #{parsed.length - runs.count} prameter_set_ids are incdluding" if runs.count != parsed.length
    runs
  end

  def validate_run_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("run_id") }
      raise "Invalid json format. Key 'run_id' is necessary."
    end
  end

  def get_analyzers(file)
    parsed = JSON.load( File.read(file) )
    validate_analyzer_ids(parsed)
    analyzers = Analyzer.in(id: parsed.map {|h| h["analyzer_id"] } )
    raise "Invalid #{parsed.length - analyzers.count} prameter_set_ids are incdluding" if analyzers.count != parsed.length
    analyzers
  end

  def validate_analyzer_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("analyzer_id") }
      raise "Invalid json format. Key 'analyzer_id' is necessary."
    end
  end

  def get_analyses(file)
    parsed = JSON.load( File.read(file) )
    validate_analysis_ids(parsed)
    Analysis.in(id: parsed.map {|h| h["analysis_id"] } )
  end

  def validate_analysis_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("analysis_id") }
      raise "Invalid json format. Key 'analysis_id' is necessary."
    end
  end

  def overwrite_file?(path)
    return yes?("Overwrite output file?") if File.exist?(path)
    return true
  end
end

