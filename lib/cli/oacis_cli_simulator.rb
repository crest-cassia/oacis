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

    existing = simulator.parameter_definitions.detect {|pd| pd.key == options[:name] }
    if existing
      casted_default = ParametersUtil.cast_value(options[:default], existing.type)
      if existing.type == options[:type] and existing.default == casted_default
        # idempotent re-run, e.g. after an interrupted migration: only sweep
        $stderr.puts "Parameter '#{options[:name]}' is already defined. Filling missing default values..."
      else
        $stderr.puts "A parameter named '#{options[:name]}' already exists " \
                     "with type=#{existing.type}, default=#{existing.default.inspect}"
        raise "validation of new parameter definition failed"
      end
    else
      new_param_def = simulator.parameter_definitions.build(key: options[:name], type: options[:type], default: options[:default])
      unless new_param_def.valid?
        $stderr.puts new_param_def.inspect
        $stderr.puts new_param_def.errors.full_messages
        raise "validation of new parameter definition failed"
      end
      # Commit the definition change first (atomic single-document update).
      # From this point on, every newly created PS is casted with the new
      # definitions: PS-creation transactions write the simulator document,
      # so they conflict with this write and retry against the committed
      # state. The sweep below therefore only has to migrate the PSs which
      # existed before the commit — no lock is needed.
      unless simulator.append_parameter_definition_atomically(new_param_def)
        $stderr.puts "Parameter '#{new_param_def.key}' was defined concurrently. Filling missing default values..."
      end
    end
    simulator.reload

    # Sweep every PS which misses any of the defined keys (not only the
    # new one) and fill them with the default values, until convergence.
    # This also repairs PSs left inconsistent by an earlier interrupted
    # migration. Keys without a default value cannot be repaired and are
    # left out.
    defaults = {}
    simulator.parameter_definitions.each {|pd| defaults[pd.key] = pd.default unless pd.default.nil? }
    loop do
      missing_any = defaults.keys.map {|key| { "v.#{key}" => { '$exists' => false } } }
      query = simulator.parameter_sets.where('$or' => missing_any)
      total = query.count
      break if total == 0
      progressbar = ProgressBar.create(total: total, format: "%t %B %p%% (%c/%C)")
      query.each do |ps|
        defaults.each do |key, default_value|
          ps.v[ key ] = default_value unless ps.v.has_key?(key)
        end
        begin
          ps.timeless.save!
        rescue Mongo::Error::OperationFailure => ex
          raise unless ParameterSet.duplicate_key_error?(ex)
          # filling the defaults made this PS identical to an existing one;
          # exempt it from the uniqueness constraint and let the user decide
          ps.unset(:fingerprint)
          $stderr.puts "WARNING: #{ps.id} became identical to an existing ParameterSet " \
                       "after filling default values; consider merging or destroying it."
        end
        progressbar.increment
      end
    end
  end
end
