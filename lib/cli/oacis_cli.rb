#!/usr/bin/env ruby

require 'thor'
require_relative '../../config/environment'

require_relative 'oacis_cli_common'
require_relative 'oacis_cli_simulator'
require_relative 'oacis_cli_parameter_set'
require_relative 'oacis_cli_run'

class OacisCli < Thor

  private
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
end
