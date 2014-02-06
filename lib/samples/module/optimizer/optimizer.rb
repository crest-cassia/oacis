require 'json'
require_relative '../OACIS_module.rb'

class Optimizer < OacisModule

  def initialize(data)
    @input_data = data

    raise "Target simulator is missing." if target_simulator.blank?

    if optimizer_data["seed"].class == String
      @prng = Random.new.marshal_load(JSON.parse(optimizer_data["seed"]))
    else
      @prng = Random.new(optimizer_data["seed"])
    end
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
    optimizer_data["data"]["iteration"] = @num_iterations
    optimizer_data["data"]["seed"] = @prng.marshal_dump.to_json
    File.open(output_file, 'w') {|io| io.print optimizer_data.to_json }
  end

  #override
  def finished?
    b=[]
    b.push(@num_iterations >= optimizer_data["data"]["max_optimizer_iteration"])
    return b.any?
  end

  def target_simulator
    @target_simulator ||= Simulator.find(@input_data["target"]["Simulator"])
  end

  def target_analzer
    @target_analyzer ||= Analyzer.find(@input_data["target"]["Analyzer"])
  end

  def target_host
    @target_host ||= Host.find(@input_data["target"]["Host"].first)
  end
 
  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions.order_by(:id.asc).map{|mpara|
      if @input_data["operation"]["settings"]["managed_parameters"].keys.include?(mpara["key"])
        mpara["range"]=@input_data["operation"]["settings"]["managed_parameters"]["range"]
      end
      mpara
    }
    parameter_definitions
  end

  def managed_parameters_table
    a = {}
    managed_parameters.each do |mpara|
    if mpara["range"].exist
      a << {"key"=>mpara["key"],"type"=>mpara["type"]}
    end
    a
  end

  def optimizer_data
    @optimizer_data ||= create_optimizer_data
  end

  def create_optimizer_data
    raise "IMPLEMENT ME"
  end
end

