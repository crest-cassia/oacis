require 'json'
require_relative '../../OACIS_module.rb'
require_relative '../../OACIS_module_data.rb'

class SampleModule < OacisModule

  # this definition is used by OACIS_module_installer
  def self.definition
    h = {}
    h["iteration"]=3
    h["num_generation"]=5
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
    result.try(:fetch, "Fitness")
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
  end
end

