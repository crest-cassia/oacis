class OacisCli < Thor

  desc 'parameter_sets_template', "print parameter_sets template"
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'target simulator',
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
    desc:     'target simulator',
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

    if options[:verbose]
      $stderr.puts "input parameter_sets :", JSON.pretty_generate(input)
      $stderr.puts "simulator :", JSON.pretty_generate(simulator)
    end

    created = input.each_with_index.map do |ps_value, idx|
      $stderr.puts "creating parameter_set : #{idx} / #{input.size}"
      $stderr.puts "  parameter values : #{ps_value.inspect}" if options[:verbose]
      param_set = simulator.parameter_sets.build({v: ps_value})
      if param_set.valid?
        param_set.save! unless options[:dry_run]
      elsif param_set.errors.keys == [:parameters] # An identical parameter_set is found
        $stderr.puts "  An identical parameter_set already exists. Skipping..."
        param_set = simulator.parameter_sets.where(v: ps_value).first
      else
        $stderr.puts param_set.inspect
        $stderr.puts param_set.errors.full_messages
        raise "validation of parameter_set failed"
      end
      param_set
    end

    return if options[:dry_run]

    # print json
    File.open(options[:output], 'w') do |io|
      io.puts "["
      rows = created.map do |ps|
        h = {"parameter_set_id" => ps.id.to_s}
        "  #{h.to_json}"
      end
      io.puts rows.join(",\n")
      io.puts "]"
      io.flush
    end
  end
end
