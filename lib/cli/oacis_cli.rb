#!/usr/bin/env ruby

require 'thor'
require_relative '../../config/environment'

require_relative 'oacis_cli_common'
require_relative 'oacis_cli_simulator'
require_relative 'oacis_cli_parameter_set'
require_relative 'oacis_cli_run'

class OacisCli < Thor

  desc 'run_status', "print run status"
  method_option :run,
    type:     :string,
    aliases:  '-r',
    desc:     'target runs',
    required: true
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
    unless File.exist?(file)
      $stderr.puts "simulator file '#{file}' is not found"
      raise "File #{file} is not found"
    end

    simulator_id = JSON.load( File.read(file) )["simulator_id"]
    Simulator.find(simulator_id)
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
