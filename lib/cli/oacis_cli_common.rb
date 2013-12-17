class OacisCli < Thor

  class_option :dry_run, type: :boolean, aliases: '-d', desc: 'dry run'
  class_option :verbose, type: :boolean, aliases: '-v', desc: 'verbose mode'

  USAGE = <<"EOS"
usage:
#1 make host.json file
  ruby oacis_cli.rb show_host -o host.json
  #check or edit host.json
#2 create simulator
  ruby oacis_cli.rb create_simulator -h host.json -i simulator.json -o simulator_id.json
  #you can get simulator.json template file "ruby oacis_cli.rb simulator_template -o simulator.json"
  #edit simulator.json (at least following fields, "name", "command", "parameter_definitions")
#3 create parameter_set
  ruby oacis_cli.rb create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json
  #you can get parameter_sets.json template file "ruby oacis_cli.rb parameter_sets_template -s simulator_id.json -o parameter_sets.json"
#4 create run template
  ruby oacis_cli.rb runs_template -p parameter_set_ids.json -h host.json -t 1 -o runs.json
#5 create run
  ruby oacis_cli.rb create_runs -p parameter_set_ids.json -h host.json -i runs.json -o run_ids.json
#6 check run status
  ruby oacis_cli.rb run_status -r run_ids.json
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
    File.open(options[:output], 'w') {|io|
      io.puts JSON.pretty_generate(hosts)
      io.flush
    }
  end
end
