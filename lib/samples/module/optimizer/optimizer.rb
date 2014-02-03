require 'json'
require_relative '../OACIS_module.rb'

class Optimizer < OacisModule

  def initialize(data)
    @input_data = data

    if target_simulator.blank?
      puts "Target simulator is missing."
      exit(-1)
    end

    if optimizer_data["data"]["seed"].class == String
      @prng = Random.new.marshal_load(JSON.parse(optimizer_data["data"]["seed"]))
    else
      @prng = Random.new(optimizer_data["data"]["seed"])
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

  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions
    @input_data["operation"]["settings"]["managed_parameters"].each do |mpara|
      parameter_definitions.where({"key"=>mpara["key"]}).first["range"]=mpara["range"]
    end
    parameter_definitions
  end

  def optimizer_data
    @optimizer_data ||= create_optimizer_data
  end

  def create_optimizer_data
    raise "IMPLEMENT ME"
  end
end

