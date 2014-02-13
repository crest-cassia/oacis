require 'json'
require_relative 'optimizer_data.rb'

class PsoModule < Optimizer

  def self.fitnessfunction(a)
    [a.inject(0.0){|sum, n| sum + n*n }]
  end

  def self.fitnessfunction_definition
    h={}
    h["dimension"]=2
    h["range"]=[]
    h["type"] = []
    h["dimension"].times do |i|
      h["range"] << [-5,5]
      h["type"] << "Float"
    end
    h
  end

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

  def self.paramater_definitions(sim)
    definition = PsoModule.definition
    definition["_optimizer_type"]="PSO" # add _optimizer_type_field for Optimizer Module
    Optimizer.paramater_definitions(sim, definition)
  end

  def initialize(data)
    data.each do |key, val|
      data[key]=JSON.parse(data[key]) if JSON.is_json?(data[key])
    end
    super(data)
    #@pso_definition = Pso.definition
    @pso_definition = data
    @prng = Random.new(@pso_definition["seed"])
    @status = {}
    @status["iteration"]=0
    #@status["iteration"]=@num_iterations
    @status["rnd_algorithm"]=@prng.marshal_dump
    @pso_definition = data
    @pa = ParticleArchive.new
    @fitnessfunction_definition = PsoModule.fitnessfunction_definition
  end

  #override
  def create_optimizer_data #this data is written in _output.json and imported to DB
    h={}
    h["data"]=@pso_definition
    @status["rnd_algorithm"]=@prng.marshal_dump.to_json
    h["status"]=@status
    h["result"]=@pa.result
    h
  end

#  def terminal_run
#    begin
#      update_particle_positions
#      evaluate_particles
#      dump_serialized_data
#      $stdout.puts "iteration#{@status["iteration"]}"
#      @status["iteration"]+=1
#    end while (!finished?)
#    "optimization is finished with iteration #{@status["iteration"]} best is #{@pa.get_best(@status["iteration"]-1)}"
#  end

  private
  def dump_serialized_data
    @status["rnd_algorithm"]=@prng.marshal_dump.to_json
    optimizer_data["status"]=@status
    super
  end

  def update_particle_positions
    if @status["iteration"]==0
      create_particles
    else
      move_particles
    end
  end

  #override
  def generate_runs #define generate_runs afeter update_particle_positions
    update_particle_positions
    generate_optimizer_runs(@status["iteration"])
  end

  #override
  def evaluate_runs
    #update fitness value
    #@pso_definition["population"].times do |i|
    #  @pa.set_fitness(@status["iteration"], i, [Pso.fitnessfunction(@pa.get_positions(@status["iteration"], i))] )
    #end
    population = @pa.result["data_sets"][@status["iteration"]].map{|d| d["input"]}
    population.each_with_index do |pos, i|
      v = {}
      managed_parameters.each do |mpara|
        index =  managed_parameters_table.map{|m| m["key"]}.index(mpara["key"])
        if index
          v[mpara["key"]] = pos[index]
        else
          v[mpara["key"]] = mpara["default"]
        end
      end
      ps = target_simulator.parameter_sets.where(v: v).first
      @pa.set_fitness(@status["iteration"], i, target_fields(ps))
    end

    #update pbest
    @pso_definition["population"].times do |i|
      h = @pa.get_datasets(@status["iteration"], i)
      if @status["iteration"] > 0 and (@pso_definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] > h["output"][0]) and (!@pso_definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] < h["output"][0])
        h = @pa.get_pbest(@status["iteration"]-1, i)
      end
      @pa.set_pbest(@status["iteration"], i, h)
    end

    #update gbest
    fitness_array = @pa.get_pbests(@status["iteration"]).map{|d| d["output"][0]}
    if @pso_definition["maximize"]
      best_key = fitness_array.sort.last
    else
      best_key = fitness_array.sort.first
    end
    best_index = fitness_array.index(best_key)
    h = {"input"=>@pa.get_pbest_positions(@status["iteration"], best_index), "output"=>[best_key]}
    if @status["iteration"] > 0 and (@pso_definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] > h["output"][0]) and (!@pso_definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] < h["output"][0])
       h = @pa.get_best(@status["iteration"]-1)
    end
    @pa.set_best(@status["iteration"], h)
    @status["iteration"] +=1
  end

  def target_fields(ps)
    anl = Analysis.where(analyzer_id: target_analzer.to_param, analyzable_id: ps.runs.first.to_param, status: :finished).first
    return [nil] if anl.blank? or anl.result.blank? or anl.result["Fitness"].blank?
    [anl.result["Fitness"]]
  end

  def finished?
    b=[]
    b.push(@status["iteration"] >= @pso_definition["iteration"])
    return b.any?
  end

  def adjust_range(x, d)
    x = @fitnessfunction_definition["range"][d][0] if x < @fitnessfunction_definition["range"][d][0]
    x = @fitnessfunction_definition["range"][d][1] if x > @fitnessfunction_definition["range"][d][1]
    x
  end

  def adjust_range_with_maneged_parameters(x, d)
    mpara = managed_parameters.select{|mp| mp["key"] == managed_parameters_table[d]["key"]}.first
    x = mpara["range"][0] if x < mpara["range"][0]
    x = mpara["range"][1] if x > mpara["range"][1]
    if mpara["range"].length ==3 and mpara["range"][2] != 0
      range = mpara["range"][2]
      case mpara["type"]
      when "Integer"
        x = (Rational((x * 1/range).to_i,1/range)).to_i
      when "Float"
        x = ((Rational((x * 1/range).to_i,1/range)).to_f).round(6)
      end
    end
    x
  end

  def create_particles
    @pso_definition["population"].times do |i|
      @fitnessfunction_definition["dimension"].times do |d|
        width = @fitnessfunction_definition["range"][d][1] - @fitnessfunction_definition["range"][d][0]
        width = width.to_f if @fitnessfunction_definition["type"][d] == "Float"
        x = @prng.rand(width) + @fitnessfunction_definition["range"][d][0]
        x = adjust_range(x, d)
        x = adjust_range_with_maneged_parameters(x, d)
        @pa.set_position(@status["iteration"], i, d, x)
        @pa.set_velocity(@status["iteration"], i, d, 0.0)
      end
    end
  end

  def move_particles
    pre_iteration = @status["iteration"]-1
    @pso_definition["population"].times do |i|
      @fitnessfunction_definition["dimension"].times do |d|
        w = (@pso_definition["w"][0] - @pso_definition["w"][1])*(1.0-pre_iteration.to_f/@pso_definition["iteration"].to_f) + @pso_definition["w"][1]
        v = w*@pa.get_velocity(pre_iteration, i, d)
        $stdout.puts "ite=#{pre_iteration}, i=#{i}, d=#{d}" if @pa.get_pbest_position(pre_iteration, i, d).nil?
        dump_serialized_data if @pa.get_pbest_position(pre_iteration, i, d).nil?
        v += @pso_definition["cp"]*@prng.rand(1.0)*(@pa.get_pbest_position(pre_iteration, i, d) - @pa.get_position(pre_iteration, i, d))
        v += @pso_definition["cg"]*@prng.rand(1.0)*(@pa.get_best_position(pre_iteration, i, d) - @pa.get_position(pre_iteration, i, d))
        x = @pa.get_position(pre_iteration, i, d) + v
        x = adjust_range(x, d)
        x = adjust_range_with_maneged_parameters(x, d)
        @pa.set_position(@status["iteration"], i, d, x)
        @pa.set_velocity(@status["iteration"], i, d, v)
      end
    end
  end

  def evaluate_particles
    #update fitness value
    @pso_definition["population"].times do |i|
      @pa.set_fitness(@status["iteration"], i, [Pso.fitnessfunction(@pa.get_positions(@status["iteration"], i))] )
    end

    #update pbest
    @pso_definition["population"].times do |i|
      h = @pa.get_datasets(@status["iteration"], i)
      if @status["iteration"] > 0 and (@pso_definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] > h["output"][0]) and (!@pso_definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] < h["output"][0])
        h = @pa.get_pbest(@status["iteration"]-1, i)
      end
      @pa.set_pbest(@status["iteration"], i, h)
    end

    #update gbest
    fitness_array = @pa.get_pbests(@status["iteration"]).map{|d| d["output"][0]}
    if @pso_definition["maximize"]
      best_key = fitness_array.sort.last
    else
      best_key = fitness_array.sort.first
    end
    best_index = fitness_array.index(best_key)
    h = {"input"=>@pa.get_pbest_positions(@status["iteration"], best_index), "output"=>[best_key]}
    if @status["iteration"] > 0 and (@pso_definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] > h["output"][0]) and (!@pso_definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] < h["output"][0])
       h = @pa.get_best(@status["iteration"]-1)
    end
      @pa.set_best(@status["iteration"], h)
  end
end

class ParticleArchive < OptimizerData

  #overwrite
  def data
    h = super
    h["velocity"] = []
    h["personal_best"] = []
    h
  end

  ##overwrite
  def result
    @result ||= data
  end

  def get_positions(iteration, index)
    get_datasets(iteration, index)["input"]
  end

  def set_positions(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_positions(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end

  def get_position(iteration, index, dim)
    get_positions(iteration, index)[dim]
  end

  def set_position(iteration, index, dim, val)
    v = get_positions(iteration, index)
    v[dim] = val
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
    result["velocity"][iteration] = [] if result["velocity"][iteration].nil?
    result["velocity"][iteration][index] ||= []
  end

  def set_velocities(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_velocities(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end

  def get_velocity(iteration, index, dim)
    result["velocity"][iteration][index][dim]
  end

  def set_velocity(iteration, index, dim, val)
    a = get_velocities(iteration, index)
    a[dim] = val
  end

  def get_pbests(iteration)
    result["personal_best"][iteration] ||= []
  end


  def get_pbest(iteration, index)
    a = get_pbests(iteration)
    a[index] ||= {}
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
    result["personal_best"][iteration] = [] if result["personal_best"][iteration].nil?
    result["personal_best"][iteration][index] = {"input"=>[], "output"=>[], "velocity"=>[]} if result["personal_best"][iteration][index].nil?
    result["personal_best"][iteration][index]["input"]
  end

  def get_pbest_position(iteration, index, dim)
    result["personal_best"][iteration] = [] if result["personal_best"][iteration].nil?
    result["personal_best"][iteration][index] = {"input"=>[], "output"=>[], "velocity"=>[]} if result["personal_best"][iteration][index].nil?
    result["personal_best"][iteration][index]["input"][dim]
  end

  def set_pbest_position(iteration, index, dim, val)
    a = get_pbest(iteration, index)
    a["input"][dim] = val
  end

  def get_best_position(iteration, index, dim)
    a = get_best(iteration)
    a["input"][dim]
  end
end

#test for ParicleArchive
#-------------------------
#pa = ParticleArchive.new
#pa.set_position(0, 0, 0, 1)
#pa.set_position(0, 0, 1, 2)
#pa.set_position(0, 0, 2, 3)
#pa.set_positions(0, 1, [21, 22, 23])
#pa.set_fitness(0, 0, [6])
#pa.set_fitness(0, 1, [66])
#pa.set_velocity(0, 0, 0, -1)
#pa.set_velocity(0, 0, 1, -2)
#pa.set_velocity(0, 0, 2, -3)
#pa.set_velocities(0, 1, [-21, -22, -23])
#pa.set_pbest(0, 0, pa.get_positions(0, 0))
#pa.set_pbest(0, 1, pa.get_positions(0, 1))
#pa.set_best(0, {"input"=>pa.get_positions(0,0),"output"=>pa.get_fitness(0,0),"velocity"=>pa.get_velocities(0,0)})
#pa.result
#-------------------------

