require 'thor'
require 'pp'
require 'json'

class OacisCli < Thor

  MESSAGE={"greeting"=>"input data with json format"}
  
  USAGE = <<"EOS"
usage:
#1 make host.json file
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb show_host > host.json
  #check or edit host.json
#2 create simulator
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb create_simulator -h host.json < simulator.json > simulator_id.json
  #you can get simulator.json template file "ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb simulator_template > simulator.json"
  #edit simulator.json (at least following fields, "name", "command", "parameter_definitions")
#3 create parameter_set
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb create_parameter_sets -s simulator_id.json < parameter_sets.json > parameter_set_ids.json
  #you can get parameter_sets.json template file "ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb parameter_sets_template -s simulator_id.json > parameter_sets.json"
#4 create run template
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb runs_template -p parameter_set_ids.json -h host.json -t 1 > runs.json
#5 create run
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb create_run -p parameter_set_ids.json -h host.json < runs.json > run_ids.json
#6 check run status
  ruby -r $OACIS_HOME/config/environment.rb oacis_cli.rb run_status -r run_ids.json
EOS

  SIMULATOR_TEMPLATE=<<"EOS"
{
  "name": "a_sample_simulator",
  "command": "$OACIS_HOME/lib/samples/tutorial/simulator/simulator.out",
  "support_input_json": false,
  "support_mpi": false,
  "support_omp": false,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
EOS

  desc 'usage', "print usage"
  def usage
    puts USAGE
  end

  desc 'show_host', "show_host"
  def show_host
    hosts = Host.all.to_a.map{|host| {"id"=>host.to_param,"name"=>host.name,"hostname"=>host.hostname,"user"=>host.user}}
    puts JSON.pretty_generate(hosts)
  end

  desc 'simulator_template', "print simulator template"
  def simulator_template
    puts SIMULATOR_TEMPLATE
  end

  desc 'create_simulator', "create_simulator"
  method_option :dry_run,
    :type     => :boolean,
    :aliases  => '-d',
    :desc     => 'dry_run (validation only)'
  method_option :verbose,
    :type     => :boolean,
    :aliases  => '-v',
    :desc     => 'show detail messages'
  method_option :host,
    :type     => :string,
    :aliases  => '-h',
    :desc     => 'executable hosts'
  def create_simulator
    puts MESSAGE["greeting"] if options[:verbose]
    stdin = STDIN
    data = JSON.load(stdin)
    unless data
      $stderr.puts "ERROR:data is not json format"
      exit(-1)
    end

    hosts = get_host(options[:host])
    data["executable_on_ids"]=hosts.map{|host| host.to_param}

    if options[:verbose]
      puts "data = "
      puts JSON.pretty_generate(data)
    end

    if create_simulator_data_is_valid?(data)
      puts  "data is valid" if options[:verbose]
    else
      puts  "data is not valid" if options[:verbose]
        exit(-1)
    end

    unless options[:dry_run]
      create_simulator_do(data)
    end
  end

  desc 'parameter_sets_template', "print parameter_sets template"
  method_option :simulator,
    :type     => :string,
    :aliases  => '-s',
    :desc     => 'target simulator',
    :required => true
  def parameter_sets_template
    sim = get_simulator(options[:simulator])
    h = {}
    ps = sim.parameter_definitions.map {|ps_def| h[ps_def["key"]]=ps_def["default"]}
    puts "["
    puts "  "+h.to_json
    puts "]"
  end

  desc 'create_parameter_sets', "create parameter_sets"
  method_option :dry_run,
    :type     => :boolean,
    :aliases  => '-d',
    :desc     => 'dry_run (validation only)'
  method_option :verbose,
    :type     => :boolean,
    :aliases  => '-v',
    :desc     => 'show detail messages'
  method_option :simulator,
    :type     => :string,
    :aliases  => '-s',
    :desc     => 'target simulator',
    :required => true
  def create_parameter_sets
    puts MESSAGE["greeting"] if options[:verbose]
    stdin = STDIN
    data = JSON.load(stdin)
    unless data
      $stderr.puts "ERROR:data is not json format"
      exit(-1)
    end

    sim = get_simulator(options[:simulator])

    if options[:verbose]
      puts "data = "
      puts JSON.pretty_generate(data)
    end

    if create_parameter_sets_data_is_valid?(data, sim)
      puts  "data is valid" if options[:verbose]
    else
      puts  "data is not valid" if options[:verbose]
        exit(-1)
    end

    unless options[:dry_run]
      create_parameter_sets_do(data, sim)
    end
  end

  desc 'runs_template', "print runs template"
  method_option :parameter_sets,
    :type     => :string,
    :aliases  => '-p',
    :desc     => 'target parameter_set',
    :required => true
  method_option :host,
    :type     => :string,
    :aliases  => '-h',
    :desc     => 'executable hosts (the first host is abailable)',
    :required => true
  method_option :times,
    :type     => :numeric,
    :aliases  => '-t',
    :desc     => 'num of creating runs'
  def runs_template
    ps = get_parameter_sets(options[:parameter_sets])
    host = get_host(options[:host]).first
    puts "["
    ps.each do |p|
      run_count = options[:times] ? options[:times] : 1
      h = {"parameter_set_id"=>p.to_param,"submitted_to_id"=>host.to_param,"times"=>run_count}
    puts p==ps.last ? "  "+h.to_json : "  "+h.to_json+","
    end
    puts "]"
  end

  desc 'create_runs', "create runs"
  method_option :dry_run,
    :type     => :boolean,
    :aliases  => '-d',
    :desc     => 'dry_run (validation only)'
  method_option :verbose,
    :type     => :boolean,
    :aliases  => '-v',
    :desc     => 'show detail messages'
  method_option :parameter_sets,
    :type     => :string,
    :aliases  => '-p',
    :desc     => 'target parameter_sets',
    :required => true
  method_option :host,
    :type     => :string,
    :aliases  => '-h',
    :desc     => 'executable hosts (the first host is abailable)',
    :required => true
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

  desc 'run_status', "print run status"
  method_option :run,
    :type     => :string,
    :aliases  => '-r',
    :desc     => 'target runs',
    :required => true
  def run_status
    count=0
    while true
      run = get_runs(options[:run])
      total=run.count
      finished=run.select {|r| r.status==:finished}.size
      show_status(total, finished, count)
      sleep 1
      count+=1
      count-=6 if count > 5
      break if total > 0 and total == finished 
    end
  end

  private
  def create_simulator_from_data(data)
    sim = Simulator.new
    sim.name = data["name"]
    sim.command = data["command"]
    data["parameter_definitions"].each do |pd|
      ps = sim.parameter_definitions.build
      ps.key = pd["key"]
      ps.type = pd["type"]
      val = pd["default"]
      val = val.to_i if pd["type"] == "Integer"
      val = val.to_f if pd["type"] == "Float"
      val = val.to_b if pd["type"] == "Boolean"
      ps.default = val
      ps.description = pd["descriotion"]
    end
    sim
  end

  def create_simulator_data_is_valid?(data)
    sim = create_simulator_from_data(data)
    sim.valid?
  end

  def create_simulator_do(data)
    sim = create_simulator_from_data(data)
    sim.save!
    h = {"simulator_id"=>sim.to_param}
    puts h.to_json
  end

  def create_parameter_sets_from_data(data, sim)
    ps = []
    data.each do |ps_def|
      temp_ps = sim.parameter_sets.build
      temp_ps.v = {}
      ps_def.each do |key, val|
        temp_ps.v[key] = val
      end
      ps.push temp_ps
    end
    ps
  end

  def create_parameter_sets_data_is_valid?(data, sim)
    ps = create_parameter_sets_from_data(data, sim)
    ps.map {|p| p.valid?}.all?
  end

  def create_parameter_sets_do(data, sim)
    ps = create_parameter_sets_from_data(data, sim)
    ps.each do |p|
      p.save!
    end
    puts "["
    ps.each do |p|
    h = {"parameter_set_id"=>p.to_param}
    puts p==ps.last ? "  "+h.to_json : "  "+h.to_json+","
    end
    puts "]"
  end

  def create_runs_from_data(data, parameter_sets, host)
    run = []
    parameter_sets.each do |ps|
      run_count = ps.runs.where({:status=>:finished}).count
      create_run_count = data.select {|conf| conf["parameter_set_id"]==ps.to_param}.first["times"] - run_count
      if create_run_count > 0
        create_run_count.times do |i|
          temp_run = ps.runs.build
          temp_run.submitted_to_id=host.to_param
          run.push temp_run
        end
      end
    end
    run
  end

  def create_runs_data_is_valid?(data, parameter_sets, host)
    run = create_runs_from_data(data, parameter_sets, host)
    run.map {|r| r.valid?}.all?
  end

  def create_runs_do(data, parameter_sets, host)
    run = create_runs_from_data(data, parameter_sets, host)
    run.each do |r|
      r.save!
    end
    puts "["
    run.each do |r|
    h = {"run_id"=>r.to_param}
    puts r==run.last ? "  "+h.to_json : "  "+h.to_json+","
    end
    puts "]"
  end

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
    if File.exist?(file)
      io = File.open(file,"r")
      parsed = JSON.load(io)
      simulator_id=parsed["simulator_id"]
    else
      $stderr.puts "simulator file '#{file}' is not exist"
      exit(-1)
    end
    if simulator_id
      sim = Simulator.find(simulator_id)
    else
      $stderr.puts "simulator_id is not existed"
      exit(-1)
    end
    sim
  end

  def get_parameter_sets(file)
    ps=[]
    if File.exist?(file)
      io = File.open(file,"r")
      parsed = JSON.load(io)
      if parsed.is_a? Array
        parsed.map{|p| p["parameter_set_id"]}.each do |parameter_set_id|
          if parameter_set_id
            temp_ps = ParameterSet.find(parameter_set_id)
          else
            $stderr.puts "parameter_set_id is not existed"
            exit(-1)
          end
          ps.push temp_ps
        end
      end
    else
      $stderr.puts "simulator file '#{file}' is not exist"
      exit(-1)
    end
    ps
  end

  def get_runs(file)
    run=[]
    if File.exist?(file)
      io = File.open(file,"r")
      parsed = JSON.load(io)
      if parsed.is_a? Array
        parsed.map{|p| p["run_id"]}.each do |run_id|
          if run_id
            temp_run = Run.find(run_id)
          else
            $stderr.puts "parameter_set_id is not existed"
            exit(-1)
          end
          run.push temp_run
        end
      end
    else
      $stderr.puts "simulator file '#{file}' is not exist"
      exit(-1)
    end
    run
  end

  def show_status(total, current, count)
    if total>0
    rate = current.to_f/total.to_f
    str = "progress:["
    20.times do |i|
    str += i < (20*rate).to_i ? "#" : "."
    end
    str += "]"
    0.upto(4) do |i|
      str += i < count ? ">" : "<"
    end
    str += "(#{current}/#{total})"
    4.downto(0) do |i|
      str += i < count ? "<" : ">"
    end
    str += total==current ? "\n" : "\r"
    print str
    else
      str = "No such run_ids"
      puts str
    end
  end
end

OacisCli.start
