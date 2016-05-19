class OacisCli < Thor

  ANALYZER_TEMPLATE=<<"EOS"
{
  "name": "a_sample_analyzer",
  "type": "on_run",
  "auto_run": "no",
  "files_to_copy": "*",
  "dwscription": "",
  "command": "gnuplot #{File.expand_path("../lib/samples/tutorial/analyzer/analyzer.plt", File.dirname(__FILE__))}",
  "support_input_json": true,
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
  desc 'analyzer_template', "print analyzer template"
  method_option :output,
    type:     :string,
    aliases:  '-o',
    desc:     'output file',
    required: true
  def analyzer_template
    return unless options[:yes] or overwrite_file?(options[:output])
    File.open(options[:output], 'w') {|io|
      io.puts ANALYZER_TEMPLATE
      io.flush
    }
  end

  desc 'create_simulator', "create_simulator"
  method_option :host,
    type:     :string,
    aliases:  '-h',
    desc:     'executable hosts'
  method_option :simulator,
    type:     :string,
    aliases:  '-s',
    desc:     'analyzer\'s simulator',
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
  def create_simulator
    input = load_json_file_or_string(options[:input])

    # create an analyzer
    # when :parameter_definitions are included in options[:input], the new anz has parameter_definitions.
    # when :executable_on_ids are included in options[:input], the new anz has executable_on.
    if options[:host]
      hosts = get_host(options[:host])
      input["executable_on_ids"] += hosts.map{|host| host.id}
      input["auto_run_submitted_to"] = hosts.first.id
    end
    sim = get_simulator(options[:simulator])
    anz = sim.analyzers.new(input)

    if options[:verbose]
      $stderr.puts "created_simulator :", JSON.pretty_generate(sim), ""
      $stderr.puts "parameter_definitions :", JSON.pretty_generate(sim.parameter_definitions)
    end

    if anz.valid?
      return unless options[:yes] or overwrite_file?(options[:output])
      anz.save!
      write_analyzer_id_to_file(options[:output], anz)
    else
      $stderr.puts anz.inspect
      $stderr.puts anz.errors.full_messages
      raise "validation of simulator failed"
    end
  end

  private
  def write_analyzer_id_to_file(path, analyzer)
    h = {"analyzer_id" => analyzer.id.to_s}
    File.open(path, 'w') {|io|
      io.puts JSON.pretty_generate(h)
      io.flush
    }
  end
end
