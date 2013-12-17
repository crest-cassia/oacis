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
    File.open(options[:output], 'w') {|io|
      io.puts JSON.pretty_generate(hosts)
      io.flush
    }
  end
end
