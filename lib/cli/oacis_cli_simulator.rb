class OacisCli < Thor

  SIMULATOR_TEMPLATE=<<"EOS"
{
  "name": "a_sample_simulator",
  "command": "#{File.expand_path("../lib/samples/tutorial/simulator/simulator.out", File.dirname(__FILE__))}",
  "support_input_json": false,
  "support_mpi": false,
  "support_omp": false,
  "print_version_command": null,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
EOS

  public
  desc 'simulator_template', "print simulator template"
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def simulator_template
    return unless options[:yes] or overwrite_file?(options[:output])
    File.open(options[:output], 'w') {|io|
      io.puts SIMULATOR_TEMPLATE
      io.flush
    }
  end

  desc 'create_simulator', "create_simulator"
  method_option :host,
    type:     :string,
    aliases:  '-h',
    desc:     'executable hosts'
  method_option :input,
    type:     :string,
    aliases:  '-i',
    desc:     'input file',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def create_simulator
    input = load_json_file_or_string(options[:input])

    # create a simulator
    # when :parameter_definitions are included in options[:input], the new sim has parameter_definitions.
    # when :executable_on_ids are included in options[:input], the new sim has executable_on.
    if options[:host]
      hosts = get_host(options[:host])
      input["executable_on_ids"] += hosts.map{|host| host.id}
    end
    sim = Simulator.new(input)

    if options[:verbose]
      $stderr.puts "created_simulator :", JSON.pretty_generate(sim), ""
      $stderr.puts "parameter_definitions :", JSON.pretty_generate(sim.parameter_definitions)
    end

    if sim.valid?
      return unless options[:yes] or overwrite_file?(options[:output])
      sim.save!
      write_simulator_id_to_file(options[:output], sim)
    else
      $stderr.puts sim.inspect
      $stderr.puts sim.errors.full_messages
      raise "validation of simulator failed"
    end
  end

  private
  def write_simulator_id_to_file(path, simulator)
    h = {"simulator_id" => simulator.id.to_s}
    File.open(path, 'w') {|io|
      io.puts JSON.pretty_generate(h)
      io.flush
    }
  end

  public
  desc 'append_parameter_definition', "append parameter definition"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
  method_option :name,
    type:     :string,
    aliases:  '-n',
    desc:     'name of the new parameter',
    required: true
  method_option :type,
    type:     :string,
    aliases:  '-t',
    desc:     'type of the new parameter',
    required: true
  method_option :default,
    type:     :string,
    aliases:  '-e',
    desc:     'default value of the new parameter',
    required: true
  def append_parameter_definition
    simulator = get_simulator(options[:simulator])

    new_param_def = simulator.parameter_definitions.build(key: options[:name], type: options[:type], default: options[:default])

    unless new_param_def.valid?
      $stderr.puts new_param_def.inspect
      $stderr.puts new_param_def.errors.full_messages
      raise "validation of new parameter definition failed"
    end

    # Block creation of new ParameterSets while the existing ones are
    # migrated, so that no PS is left without the new key.
    unless simulator.lock_parameter_definitions_update
      raise "Another update of parameter definitions is in progress for this simulator. Try again later."
    end
    begin
      key = new_param_def.key
      # Repeat until no PS misses the new key: a PS whose creation
      # started just before the lock was taken is picked up by the next sweep.
      loop do
        query = simulator.parameter_sets.where("v.#{key}" => { '$exists' => false })
        total = query.count
        break if total == 0
        progressbar = ProgressBar.create(total: total, format: "%t %B %p%% (%c/%C)")
        query.each do |ps|
          ps.v[ key ] = new_param_def.default
          ps.timeless.save!
          progressbar.increment
        end
      end
      new_param_def.save!
    ensure
      simulator.unlock_parameter_definitions_update
    end
  end
end
