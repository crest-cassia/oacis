require 'json'
require_relative '../OACIS_module.rb'

class Optimizer < OacisModule

  def initialize(data)
    @input_data = data
    raise "Target simulator is missing." if target_simulator.blank?
  end

  def self.paramater_definitions(sim, v)
    raise "val is not a Hash" unless v.is_a?(Hash)
    a = []
    v.each do |key, val|
      pd = sim.parameter_definitions.build
      pd["key"] = key
      default_val = val
      default_val = val.to_json if val.is_a?(Hash) or val.is_a?(Array)
      pd["default"] = default_val
      parameter_type = "Integer" if val.is_a?(Integer)
      parameter_type = "Float" if val.is_a?(Float)
      parameter_type = "Boolean" if val.is_a?(TrueClass) or val.is_a?(FalseClass)
      parameter_type = "String" if val.is_a?(String) or val.is_a?(Hash) or val.is_a?(Array)
      pd["type"] = parameter_type
      a << pd
    end
    a
  end

  private
  #override
  def generate_runs
    raise "IMPLEMENT ME"
  end

  #override
  def evaluate_runs
    raise "IMPLEMENT ME"
  end

  #override
  def dump_serialized_data
    output_file = "_output.json"
    File.open(output_file, 'w') {|io| io.print optimizer_data.to_json }
  end

  #override
  def finished?
    raise "IMPLEMENT ME"
  end

  def target_simulator
    @target_simulator ||= Simulator.find(@input_data["_target"]["Simulator"])
  end

  def target_analzer
    @target_analyzer ||= Analyzer.find(@input_data["_target"]["Analyzer"])
  end

  def target_host
    @target_host ||= Host.find(@input_data["_target"]["Host"].first)
  end
 
  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions.order_by(:id.asc).map{|pd|
      @input_data["_managed_parameters"].each do |mp|
        pd["range"]=mp["range"] if pd["key"] == mp["key"]
      end
      pd
    }
    parameter_definitions
  end

  def managed_parameters_table
    a = []
    managed_parameters.each do |mpara|
      if mpara["range"].present?
        a << {"key"=>mpara["key"],"type"=>mpara["type"]}
      end
    end
    a
  end

  #for dump and restart
  def optimizer_data
    @optimizer_data ||= create_optimizer_data
  end

  def create_optimizer_data
    raise "IMPLEMENT ME"
  end

  def  generate_optimizer_runs(iteration)
    generated = []
    population = optimizer_data["result"]["data_sets"][iteration].map{|d| d["input"]}
    population.each do |pos|
      v = {}
      managed_parameters.each do |mpara|
        index =  managed_parameters_table.map{|m| m["key"]}.index(mpara["key"])
        if index
          v[mpara["key"]] = pos[index]
        else
          v[mpara["key"]] = mpara["default"]
        end
      end
      ps = target_simulator.parameter_sets.find_or_create_by(v: v)
      if ps.runs.count == 0
        run = ps.runs.build
        run.submitted_to_id=target_host
        run.save
        generated << run
      end
    end
    generated
  end
end

