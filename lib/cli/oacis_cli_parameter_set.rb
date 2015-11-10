class OacisCli < Thor

  desc 'parameter_sets_template', "print parameter_sets template"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def parameter_sets_template
    sim = get_simulator(options[:simulator])
    mapped = sim.parameter_definitions.map {|pdef| [pdef["key"], pdef["default"]] }
    parameter_set = Hash[mapped]

    return if options[:dry_run]
    return unless options[:yes] or overwrite_file?(options[:output])
    File.open(options[:output], 'w') do |io|
      # for visibility, manually print the json object as follows
      io.puts "[", "  #{parameter_set.to_json}", "]"
      io.flush
    end
  end

  desc 'create_parameter_sets', "create parameter_sets"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'simulator ID or path to simulator_id.json',
    required: true
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
  method_option :run,
    type:     :string,
    aliases:  '-r',
    desc:     'run options',
    required: false
  def create_parameter_sets
    input = load_json_file_or_string(options[:input])
    simulator = get_simulator(options[:simulator])

    input = expand_input(input)
    input = check_uniqueness(input, simulator)

    progressbar = ProgressBar.create(total: input.size, format: "%t %B %p%% (%c/%C)")
    if options[:verbose]
      progressbar.log "input parameter_sets :", JSON.pretty_generate(input)
      progressbar.log "simulator :", JSON.pretty_generate(JSON.load(simulator.to_json))
    end

    parameter_set_ids = []
    input.each_with_index.map do |psid_value|
      ps_value = psid_value[:value]
      progressbar.log "  parameter values : #{ps_value.inspect}" if options[:verbose]
      param_set = simulator.parameter_sets.build({v: ps_value, skip_check_uniquness: true})
      if (! psid_value[:id]) and param_set.valid?
        param_set.save! unless options[:dry_run]
        parameter_set_ids << param_set.id
      elsif psid_value[:id] # An identical parameter_set is found
        progressbar.log "  An identical parameter_set already exists. Skipping..."
        parameter_set_ids << psid_value[:id]
        # do not use 'ps_value' instead of 'param_set.v'.
        # Otherwise the existing ps is not found because 'ps_value' is not casted and ordered properly.
      else
        progressbar.log param_set.inspect
        progressbar.log param_set.errors.full_messages
        raise "validation of parameter_set failed"
      end
      progressbar.increment
    end

    if options[:run]
      run_option = load_json_file_or_string(options[:run])
      num_runs = run_option["num_runs"]
      raise "num_runs must be an Integer" unless num_runs.is_a?(Integer)
      submitted_to = run_option["submitted_to"] ? Host.find(run_option["submitted_to"]) : nil
      host_parameters = run_option["host_parameters"] || {}
      mpi_procs = run_option["mpi_procs"] || 1
      omp_threads = run_option["omp_threads"] || 1
      priority = run_option["priority"] || 1
      parameter_sets = ParameterSet.in(id: parameter_set_ids)

      create_runs_impl(parameter_sets, num_runs, submitted_to, host_parameters, mpi_procs, omp_threads, priority, [])
    end

  ensure
    return if options[:dry_run]
    return unless options[:yes] or overwrite_file?(options[:output])
    write_parameter_set_ids_to_file(options[:output], parameter_set_ids)
  end

  private
  def expand_input(input)
    if input.is_a?(Array)
      input.map {|ps_hash| expand_hash(ps_hash) }.flatten(1)
    elsif input.is_a?(Hash)
      expand_hash(input)
    else
      raise "invalid input format"
    end
  end

  def expand_hash(ps_hash)
    expanded = [ps_hash]
    ps_hash.keys.each do |key|
      expanded = expanded.map do |h|
        expand_hash_for_key(h, key)
      end
      expanded.flatten!(1)
    end
    expanded
  end

  def expand_hash_for_key(h, key)
    if h[key].is_a?(Array)
      h[key].map do |val|
        dupped = h.dup
        dupped[key] = val
        dupped
      end
    else
      [h]
    end
  end

  def check_uniqueness(input, simulator)
    old_size = input.size
    input.uniq! # this operation can remove {p2:0, p1:0} from [{p1:0, p2:0}, {p2:0, p1:0}]
    if old_size > input.size
      raise "same parameter values exist in input file"
    end
    param_defs = simulator.parameter_definitions
    input.map! do |ps_v|
      key_val_array = param_defs.map do |pd|
        val = ps_v[pd.key]
        # since JSON does not distinguish Integer and Float, we must cast the given value
        if pd.type == "Integer"
          raise "invalid type: #{pd.key}, #{val}" unless val.is_a?(Numeric)
          val = val.to_i
        elsif pd.type == "Float"
          raise "invalid type: #{pd.key}, #{val}" unless val.is_a?(Numeric)
          val = val.to_f
        end
        [pd.key, val]
      end
      Hash[key_val_array]
    end
    list_created_ps = {}
    ParameterSet.collection.aggregate(
      { '$match' => {'v' => {'$in'=>input}} },
      { '$group' => {'_id' => '$_id', v: {'$first' => '$v'}} }
    ).each do |psid_v|
      list_created_ps[psid_v['v']]=psid_v['_id']
    end
    input.map do |ps_v|
      if list_created_ps[ps_v]
        id = list_created_ps[ps_v]
        value = ps_v
      else
        id = nil
        value = ps_v
      end
      {
        id: id,
        value: value
      }
    end
  end

  def write_parameter_set_ids_to_file(path, parameter_set_ids)
    return unless parameter_set_ids.present?
    File.open(path, 'w') do |io|
      io.puts "["
      rows = parameter_set_ids.map do |psid|
        h = {"parameter_set_id" => psid.to_s}
        "  #{h.to_json}"
      end
      io.puts rows.join(",\n")
      io.puts "]"
      io.flush
    end
  end
end

