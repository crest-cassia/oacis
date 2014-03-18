require 'json'
require_relative '../../OACIS_module.rb'
require_relative '../../OACIS_module_data.rb'

class Pso < OacisModule

  # this definition is used by OACIS_module_installer
  def self.definition
    h = {}
    h["iteration"]=100
    h["population"]=10
    h["w"]=[0.729,0.729]
    h["cp"]=1.494
    h["cg"]=1.494
    h["seed"]=0
    h["maximize"]=false
    h
  end

  # data contains definitions whose values are given as ParameterSet.v in OACIS_module_simulator
  def initialize(_input_data)
    super(_input_data)

    #create some aliases
    @pso_definition = Pso.definition.keys.map {|k| {k => module_data.data["_input_data"][k]}}.inject({}) {|h, val| h.merge!(val)}
  end

  def create_or_restore_module_data
    super
    if File.exists?("_output.json")
      @prng = Random.new.marshal_load(JSON.parse(module_data.data["_status"]["rnd_algorithm"]))
    else
      @prng = Random.new(module_data.data["_input_data"]["seed"])
      module_data.data["_status"]["rnd_algorithm"]=@prng.marshal_dump.to_json
    end
  end

  #override
  def create_module_data
    PsoOptimizerData.new
  end

  private
  def update_particle_positions
    if @num_iterations==0
      create_particles
    else
      move_particles
    end
  end

  def create_particles
    @pso_definition["population"].times do |i|
      managed_parameters_table.each_with_index do |mp_table, d|
        width = mp_table["range"][1] - mp_table["range"][0]
        width = width.to_f if mp_table["type"] == "Float"
        x = @prng.rand(width) + mp_table["range"][0]
        module_data.set_position(@num_iterations, i, x, d)
        module_data.set_velocity(@num_iterations, i, 0.0, d)
      end
    end
  end

  def move_particles
    pre_iteration = @num_iterations-1
    @pso_definition["population"].times do |i|
      managed_parameters_table.length.times do |d|
        w = (@pso_definition["w"][0] - @pso_definition["w"][1])*(1.0-pre_iteration.to_f/@pso_definition["iteration"].to_f) + @pso_definition["w"][1]
        v = w*module_data.get_velocity(pre_iteration, i, d)
        $stdout.puts "ite=#{pre_iteration}, i=#{i}, d=#{d}" if module_data.get_pbest_position(pre_iteration, i, d).nil?
        dump_serialized_data if module_data.get_pbest_position(pre_iteration, i, d).nil?
        v += @pso_definition["cp"]*@prng.rand(1.0)*(module_data.get_pbest_position(pre_iteration, i, d) - module_data.get_position(pre_iteration, i, d))
        v += @pso_definition["cg"]*@prng.rand(1.0)*(module_data.get_best_position(pre_iteration, i, d) - module_data.get_position(pre_iteration, i, d))
        x = module_data.get_position(pre_iteration, i, d) + v
        module_data.set_position(@num_iterations, i, x, d)
        module_data.set_velocity(@num_iterations, i, v, d)
      end
    end
  end

  def update_status
    #update pbest
    @pso_definition["population"].times do |i|
      h = {}
      h["output"] = module_data.get_datasets(@num_iterations, i)["output"]
      h["input"] = module_data.get_position(@num_iterations, i)
      if @num_iterations > 0 and ((@pso_definition["maximize"] and module_data.get_pbest(@num_iterations-1, i)["output"][0] >= h["output"][0]) or (!@pso_definition["maximize"] and module_data.get_pbest(@num_iterations-1, i)["output"][0] <= h["output"][0]))
        h = module_data.get_pbest(@num_iterations-1, i)
      end
      module_data.set_pbest(@num_iterations, i, h)
    end
    #update gbest
    fitness_array = module_data.get_pbests(@num_iterations).map{|d| d["output"][0]}
    if @pso_definition["maximize"]
      best_key = fitness_array.sort.last
    else
      best_key = fitness_array.sort.first
    end
    best_index = fitness_array.index(best_key)
    h = {"input"=>module_data.get_pbest_position(@num_iterations, best_index), "output"=>[best_key]}
    if @num_iterations > 0 and ((@pso_definition["maximize"] and module_data.get_best(@num_iterations-1)["output"][0] >= h["output"][0]) or (!@pso_definition["maximize"] and module_data.get_best(@num_iterations-1)["output"][0] <= h["output"][0]))
       h = module_data.get_best(@num_iterations-1)
    end
    module_data.set_best(@num_iterations, h)
  end

  #override
  def get_target_fields(result)
    result.try(:fetch, "Fitness")
  end

  #override
  def generate_runs #define generate_runs afeter update_particle_positions
    update_particle_positions
    super
  end

  #override
  def evaluate_runs
    super
    update_status
 end

  #override
  def finished?
    b=[]
    b.push(@num_iterations >= @pso_definition["iteration"])
    return b.any?
  end
end

class PsoOptimizerData < OacisModuleData

  private
  #overwrite
  def data_struct
    h = super
    h["best"] = [] # h["best"][index] = [{"input"=>[],"output"=>[]}, {"input"=>[], ...}, ...]
    h["position"] = [] # h["position"][index] = [0.1, 0.2, 0.3, ...]
    h["velocity"] = [] # h["velocity"][index] = [10.0, 20.0, 30.0, ...]
    h["personal_best"] = [] # h["personal_best"][index] = [{"input"=>[], "output"=>[]}, {"input"=>[], ...}, ...]
    h
  end

  public
  #overwrite
  def data
    @data ||= data_struct
  end

  def get_best(iteration)
    data["best"][iteration] ||= {"input"=>[],"output"=>[]}
  end

  def set_best(iteration, val)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    val.each do |key,val|
      get_best(iteration)[key]=val
    end
  end

  def get_best_position(iteration, index, dim)
    a = get_best(iteration)
    a["input"][dim]
  end

  def get_position(iteration, index, *dim)
    data["position"][iteration] ||= []
    data["position"][iteration][index] ||= []
    dim.empty? ? data["position"][iteration][index] : data["position"][iteration][index][dim[0]]
  end

  def set_position(iteration, index, val, *dim)
    a = get_position(iteration, index)
    h = get_datasets(iteration, index)
    if dim.empty?
      raise "val must be a Array" unless val.is_a?(Array)
      val.each_with_index do |v, d|
        a[d] = v
        h["input"][d] = v
      end
    else
      a[dim[0]] = val
      h["input"][dim[0]] = val
    end
  end

  def get_velocity(iteration, index, *dim)
    data["velocity"][iteration] ||= []
    data["velocity"][iteration][index] ||= []
    dim.empty? ? data["velocity"][iteration][index] : data["velocity"][iteration][index][dim[0]]
  end

  def set_velocity(iteration, index, val, *dim)
    a = get_velocity(iteration, index)
    if dim.empty?
      raise "val must be a Array" unless val.is_a?(Array)
      val.each_with_index do |v, d|
        a[d] = v
      end
    else
      a[dim[0]] = val
    end
  end

  def get_pbests(iteration)
    data["personal_best"][iteration] ||= []
  end

  def get_pbest(iteration, index)
    a = get_pbests(iteration)
    a[index] ||= {"input"=>[],"output"=>[]}
  end

  def set_pbest(iteration, index, val)
    raise "val must be a Hash" unless val.is_a?(Hash)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    h = get_pbest(iteration, index)
    val.each do |k, v|
      h[k] = v
    end
  end

  def get_pbest_position(iteration, index, *dim)
    a = get_pbests(iteration)
    a[index] ||= {"input"=>[], "output"=>[]}
    dim.empty? ? a[index]["input"] : a[index]["input"][dim[0]]
  end

  def get_fitness(iteration, index)
    get_output(iteration, index)
  end

  def set_fitness(iteration, index, val)
    set_output(iteration, index, val)
  end
end

