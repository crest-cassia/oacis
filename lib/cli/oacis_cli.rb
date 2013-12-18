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
    parsed = JSON.load( File.read(file) )
    validate_simulator_id(parsed)
    Simulator.find(parsed["simulator_id"])
  end

  def validate_simulator_id(parsed)
    unless parsed.is_a?(Hash) and parsed.has_key?("simulator_id")
      raise "Invalid json format. Must be a Hash having 'simulator_id' key."
    end
  end

  def get_parameter_sets(file)
    parsed = JSON.load( File.read(file) )
    validate_parameter_set_ids(parsed)
    parsed.map {|h| ParameterSet.find( h["parameter_set_id"] ) }
  end

  def validate_parameter_set_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("parameter_set_id") }
      raise "Invalid json format. Key 'parameter_set_id' is necessary."
    end
  end

  def get_runs(file)
    parsed = JSON.load( File.read(file) )
    validate_run_ids(parsed)
    parsed.map {|h| Run.find(h["run_id"]) }
  end

  def validate_run_ids(parsed)
    unless parsed.is_a?(Array)
      raise "Invalid json format. Must be an Array"
    end
    unless parsed.all? {|h| h.has_key?("run_id") }
      raise "Invalid json format. Key 'run_id' is necessary."
    end
  end
end
