require 'json'
require_relative '../OACIS_module.rb'
require_relative '../OACIS_module_data.rb'

class Pso < OacisModule

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

  def initialize(data)
    data["w"] = JSON.parse(data["w"])
    super(data)
    @pso_definition = data

    @pso_definition["seed"] = JSON.parse(@pso_definition["seed"]) if JSON.is_json?(@pso_definition["seed"])
    @prng = Random.new(@pso_definition["seed"])
    @status = {}
    @status["iteration"]=0
    @status["rnd_algorithm"]=@prng.marshal_dump.to_json
    @opt_data = module_data
  end

  #override
  def create_module_data #this data is written in _output.json and imported to DB
    data = PsoOptimizerData.new
    data.data["definition"]=@pso_definition
    @status["rnd_algorithm"]=@prng.marshal_dump.to_json
    data.data["status"]=@status
    data
  end

  private
  def update_particle_positions
    if @status["iteration"]==0
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
        @opt_data.set_position(@status["iteration"], i, d, x)
        @opt_data.set_velocity(@status["iteration"], i, d, 0.0)
      end
    end
  end

  def move_particles
    pre_iteration = @status["iteration"]-1
    @pso_definition["population"].times do |i|
      managed_parameters_table.length.times do |d|
        w = (@pso_definition["w"][0] - @pso_definition["w"][1])*(1.0-pre_iteration.to_f/@pso_definition["iteration"].to_f) + @pso_definition["w"][1]
        v = w*@opt_data.get_velocity(pre_iteration, i, d)
        $stdout.puts "ite=#{pre_iteration}, i=#{i}, d=#{d}" if @opt_data.get_pbest_position(pre_iteration, i, d).nil?
        dump_serialized_data if @opt_data.get_pbest_position(pre_iteration, i, d).nil?
        v += @pso_definition["cp"]*@prng.rand(1.0)*(@opt_data.get_pbest_position(pre_iteration, i, d) - @opt_data.get_position(pre_iteration, i, d))
        v += @pso_definition["cg"]*@prng.rand(1.0)*(@opt_data.get_best_position(pre_iteration, i, d) - @opt_data.get_position(pre_iteration, i, d))
        x = @opt_data.get_position(pre_iteration, i, d) + v
        @opt_data.set_position(@status["iteration"], i, d, x)
        @opt_data.set_velocity(@status["iteration"], i, d, v)
      end
    end
  end

  def evaluate_particles
    #update fitness value
    @pso_definition["population"].times do |i|
      @opt_data.set_fitness(@status["iteration"], i, [Pso.fitnessfunction(@opt_data.get_positions(@status["iteration"], i))] )
    end
  end

  def update_status
    #update pbest
    @pso_definition["population"].times do |i|
      h = {}
      h["output"] = @opt_data.get_datasets(@status["iteration"], i)["output"]
      h["input"] = @opt_data.get_positions(@status["iteration"], i)
      if @status["iteration"] > 0 and ((@pso_definition["maximize"] and @opt_data.get_pbest(@status["iteration"]-1, i)["output"][0] > h["output"][0]) or (!@pso_definition["maximize"] and @opt_data.get_pbest(@status["iteration"]-1, i)["output"][0] < h["output"][0]))
        h = @opt_data.get_pbest(@status["iteration"]-1, i)
      end
      @opt_data.set_pbest(@status["iteration"], i, h)
    end

    #update gbest
    fitness_array = @opt_data.get_pbests(@status["iteration"]).map{|d| d["output"][0]}
    if @pso_definition["maximize"]
      best_key = fitness_array.sort.last
    else
      best_key = fitness_array.sort.first
    end
    best_index = fitness_array.index(best_key)
    h = {"input"=>@opt_data.get_pbest_positions(@status["iteration"], best_index), "output"=>[best_key]}
    if @status["iteration"] > 0 and ((@pso_definition["maximize"] and @opt_data.get_best(@status["iteration"]-1)["output"][0] > h["output"][0]) or (!@pso_definition["maximize"] and @opt_data.get_best(@status["iteration"]-1)["output"][0] < h["output"][0]))
       h = @opt_data.get_best(@status["iteration"]-1)
    end
    @opt_data.set_best(@status["iteration"], h)
    @status["iteration"] +=1
  end

  #override
  def get_target_fields(result)
    [result.try(:fetch, "Fitness")]
  end

  #override
  def dump_serialized_data
    @status["rnd_algorithm"]=@prng.marshal_dump.to_json
    super
  end

  #override
  def generate_runs #define generate_runs afeter update_particle_positions
    update_particle_positions
    generate_runs_iteration(@status["iteration"])
  end

  #override
  def evaluate_runs
    evaluate_runs_iteration(@status["iteration"])
    update_status
 end

  #override
  def finished?
    b=[]
    b.push(@status["iteration"] >= @pso_definition["iteration"])
    return b.any?
  end
end

class PsoOptimizerData < OacisModuleData

  private
  #overwrite
  def data_struct
    h = super
    h["best"] = [] #[{"input"=>[5,0],"output"=>[25]}, ..., {"input"=>[0,0],"output"=>[0]}]
    h["position"] = []
    h["velocity"] = []
    h["personal_best"] = []
    h
  end

  public
  #overwrite
  def data
    @data ||= data_struct
  end

  def get_best_position(iteration, index, dim)
    a = get_best(iteration)
    a["input"][dim]
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

  def get_positions(iteration, index)
    data["position"][iteration] = [] if data["position"][iteration].nil?
    data["position"][iteration][index] ||= []
  end

  def set_positions(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_positions(iteration, index)
    h = get_datasets(iteration, index)
    val.each_with_index do |v, d|
      a[d] = v
      h["input"][d] = v
    end
  end

  def get_position(iteration, index, dim)
    get_positions(iteration, index)[dim]
  end

  def set_position(iteration, index, dim, val)
    v = get_positions(iteration, index)
    v[dim] = val
    h = get_datasets(iteration, index)
    h["input"][dim] = val
  end

  def get_fitness(iteration, index)
    get_datasets(iteration, index)["output"]
  end

  def set_fitness(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_fitness(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end

  def get_velocities(iteration, index)
    data["velocity"][iteration] = [] if data["velocity"][iteration].nil?
    data["velocity"][iteration][index] ||= []
  end

  def set_velocities(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_velocities(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end

  def get_velocity(iteration, index, dim)
    data["velocity"][iteration][index][dim]
  end

  def set_velocity(iteration, index, dim, val)
    a = get_velocities(iteration, index)
    a[dim] = val
  end

  def set_pbest_position(iteration, index, dim, val)
    a = get_pbest(iteration, index)
    a["input"][dim] = val
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

  def get_pbest_positions(iteration, index)
    data["personal_best"][iteration] = [] if data["personal_best"][iteration].nil?
    data["personal_best"][iteration][index] = {"input"=>[], "output"=>[], "velocity"=>[]} if data["personal_best"][iteration][index].nil?
    data["personal_best"][iteration][index]["input"]
  end

  def get_pbest_position(iteration, index, dim)
    data["personal_best"][iteration] = [] if data["personal_best"][iteration].nil?
    data["personal_best"][iteration][index] = {"input"=>[], "output"=>[], "velocity"=>[]} if data["personal_best"][iteration][index].nil?
    data["personal_best"][iteration][index]["input"][dim]
  end
end

