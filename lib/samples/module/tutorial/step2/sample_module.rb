require 'json'
require_relative '../../OACIS_module.rb'
require_relative '../../OACIS_module_data.rb'

class SampleModule < OacisModule

  # this definition is used by OACIS_module_installer
  def self.definition
    h = {}
    h["iteration"]=3
    h["num_generation"]=5
    h["evaluate_key"]="Fitness"
    h["seed"]=0
    h
  end

  # data contains definitions whose values are given as ParameterSet.v in OACIS_module_simulator
  def initialize(_input_data)
    super(_input_data)
    @prng = Random.new(module_data.data["_input_data"]["seed"])
  end

  private
  #override
  def get_target_fields(result)
    result.try(:fetch, module_data.data["_input_data"]["evaluate_key"])
  end

  #override
  def generate_runs #define generate_runs afeter update_particle_positions
    set_parameter
    super
  end

  #override
  def evaluate_runs
    super
    evaluate_parameter
 end

  #override
  def finished?
    b=[]
    b.push(@num_iterations >= module_data.data["_input_data"]["iteration"])
    return b.any?
  end

  #override
  def create_module_data
    SampleModuleData.new
  end

  def set_parameter
    #generate new parameter values
    @input = []
    module_data.data["_input_data"]["num_generation"].times do |index|
      a = []
      managed_parameters_table.each do |mpt|
        a << @prng.rand(mpt["range"][1] - mpt["range"][0]) + mpt["range"][0]
      end
      @input << a
    end

    #set parameter value to module_data
    @input.each_with_index do |val, i|
      module_data.set_input(@num_iterations, i, val)
    end
  end

  def evaluate_parameter
    @input.each_with_index do |ps, i|
      puts "input=#{ps} output=#{module_data.get_output(@num_iterations, i)}"
    end

    outputs = @input.map.with_index {|ps, i| module_data.get_output(@num_iterations, i)}
    max_val = outputs.max
    puts "The maximum is #{max_val}"

    max_index = outputs.index(max_val)
    max_datasets = module_data.get_datasets(@num_iterations, max_index)
    module_data.set_maximum(@num_iterations, max_datasets)
  end
end

class SampleModuleData < OacisModuleData

  private
  #overwrite
  def data_struct
    h = super
    h["maximum"] = [] # h["best"][index] = [{"input"=>[],"output"=>[]}, {"input"=>[], ...}, ...]
    h
  end

  public
  def get_maximum(iteration)
    data["maximum"][iteration] ||= {"input"=>[],"output"=>[]}
  end

  def set_maximum(iteration, val)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    val.each do |key,val|
      get_maximum(iteration)[key]=val
    end
  end
end

