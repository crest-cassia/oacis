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
  def create_parameter_sets
    input = JSON.load(File.read(options[:input]))
    simulator = get_simulator(options[:simulator])

    progressbar = ProgressBar.create(total: input.size, format: "%t %B %p%% (%c/%C)")
    if options[:verbose]
      progressbar.log "input parameter_sets :", JSON.pretty_generate(input)
      progressbar.log "simulator :", JSON.pretty_generate(JSON.load(simulator.to_json))
    end

    parameter_sets = []
    input.each_with_index.map do |ps_value, idx|
      progressbar.log "  parameter values : #{ps_value.inspect}" if options[:verbose]
      param_set = simulator.parameter_sets.build({v: ps_value})
      if param_set.valid?
        param_set.save! unless options[:dry_run]
        parameter_sets << param_set
      elsif param_set.errors.keys == [:parameters] # An identical parameter_set is found
        progressbar.log "  An identical parameter_set already exists. Skipping..."
        parameter_sets << simulator.parameter_sets.where(v: ps_value).first
      else
        progressbar.log param_set.inspect
        progressbar.log param_set.errors.full_messages
        raise "validation of parameter_set failed"
      end
      progressbar.increment
    end

  ensure
    write_parameter_set_ids_to_file(options[:output], parameter_sets) unless options[:dry_run]
  end

  private
  def write_parameter_set_ids_to_file(path, parameter_sets)
    return unless parameter_sets.present?
    File.open(path, 'w') do |io|
      io.puts "["
      rows = parameter_sets.map do |ps|
        h = {"parameter_set_id" => ps.id.to_s}
        "  #{h.to_json}"
      end
      io.puts rows.join(",\n")
      io.puts "]"
      io.flush
    end
  end
end
