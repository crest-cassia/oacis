require 'json'
require_relative 'optimizer_data.rb'

class Pso

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

  def initialize()
    @prng = Random.new(Pso.definition["seed"])
    @pa = ParticleArchive.new
    @status = {}
    @status["iteration"]=0
    @status["rnd_algorithm"]=@prng.marshal_dump
  end

  def terminal_run
    begin
      update_particle_positions
      #generate_runs
      #evaluate_runs
      evaluate_particles
      dump_serialized_data
      $stdout.puts "iteration#{@status["iteration"]}"
      @status["iteration"]+=1
    end while (!finished?)
    "optimization is finished with iteration #{@status["iteration"]} best is #{@pa.get_best(@status["iteration"]-1)}"
  end

  private
  def dump_serialized_data
    h={}
    h["data"]=Pso.definition
    #@status["iteration"]=@num_iterations
    @status["rnd_algorithm"]=@prng.marshal_dump
    h["status"]=@status
    h["result"]=@pa.result
    File.open("_output.json", 'w') {|io| io.print h.to_json }
    h
  end

  def update_particle_positions
    if @status["iteration"]==0
      create_particles
    else
      move_particles
    end
  end

#  def generate_runs
#  end

#  def evaluate_runs
#  end

  def finished?
    b=[]
    b.push(@status["iteration"] >= Pso.definition["iteration"])
    #b.push(super)
    return b.any?
  end

  def adjust_range(x, d)
    x = Pso.fitnessfunction_definition["range"][d][0] if x < Pso.fitnessfunction_definition["range"][d][0]
    x = Pso.fitnessfunction_definition["range"][d][1] if x > Pso.fitnessfunction_definition["range"][d][1]
    if Pso.fitnessfunction_definition["range"][d].length ==3 and Pso.fitnessfunction_definition["range"][d][2] != 0
      case Pso.fitnessfunction_definition["type"][d]
      when "Integer"
        x = (Rational((x * 1/Pso.fitnessfunction_definition["range"][d][2]).to_i,1/Pso.fitnessfunction_definition["range"][d][2])).to_i
      when "Float"
        x = ((Rational((x * 1/Pso.fitnessfunction_definition["range"][d][2]).to_i,1/Pso.fitnessfunction_definition["range"][d][2])).to_f).round(6)
      end
    end
  end

  def create_particles
    Pso.definition["population"].times do |i|
      Pso.fitnessfunction_definition["dimension"].times do |d|
        width = Pso.fitnessfunction_definition["range"][d][1] - Pso.fitnessfunction_definition["range"][d][0]
        width = width.to_f if Pso.fitnessfunction_definition["type"][d] == "Float"
        x = @prng.rand(width) + Pso.fitnessfunction_definition["range"][d][0]
        adjust_range(x, d)
        @pa.set_position(@status["iteration"], i, d, x)
        @pa.set_velocity(@status["iteration"], i, d, 0.0)
      end
    end
  end

  def move_particles
    pre_iteration = @status["iteration"]-1
    Pso.definition["population"].times do |i|
      Pso.fitnessfunction_definition["dimension"].times do |d|
        w = (Pso.definition["w"][0] - Pso.definition["w"][1])*(1.0-pre_iteration.to_f/Pso.definition["iteration"].to_f) + Pso.definition["w"][1]
        v = w*@pa.get_velocity(pre_iteration, i, d)
        $stdout.puts "ite=#{pre_iteration}, i=#{i}, d=#{d}" if @pa.get_pbest_position(pre_iteration, i, d).nil?
        dump_serialized_data if @pa.get_pbest_position(pre_iteration, i, d).nil?
        v += Pso.definition["cp"]*@prng.rand(1.0)*(@pa.get_pbest_position(pre_iteration, i, d) - @pa.get_position(pre_iteration, i, d))
        v += Pso.definition["cg"]*@prng.rand(1.0)*(@pa.get_best_position(pre_iteration, i, d) - @pa.get_position(pre_iteration, i, d))
        x = @pa.get_position(pre_iteration, i, d) + v
        adjust_range(x, d)
        @pa.set_position(@status["iteration"], i, d, x)
        @pa.set_velocity(@status["iteration"], i, d, v)
      end
    end
  end

  def evaluate_particles
    #update fitness value
    Pso.definition["population"].times do |i|
      @pa.set_fitness(@status["iteration"], i, [Pso.fitnessfunction(@pa.get_positions(@status["iteration"], i))] )
    end

    #update pbest
    Pso.definition["population"].times do |i|
      h = @pa.get_datasets(@status["iteration"], i)
      if @status["iteration"] > 0 and (Pso.definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] > h["output"][0]) and (!Pso.definition["maximize"] and @pa.get_pbest(@status["iteration"]-1, i)["output"][0] < h["output"][0])
        h = @pa.get_pbest(@status["iteration"]-1, i)
      end
      @pa.set_pbest(@status["iteration"], i, h)
    end

    #update gbest
    fitness_array = @pa.get_pbests(@status["iteration"]).map{|d| d["output"][0]}
    if Pso.definition["maximize"]
      best_key = fitness_array.sort.last
    else
      best_key = fitness_array.sort.first
    end
    best_index = fitness_array.index(best_key)
    h = {"input"=>@pa.get_pbest_positions(@status["iteration"], best_index), "output"=>[best_key]}
    if @status["iteration"] > 0 and (Pso.definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] > h["output"][0]) and (!Pso.definition["maximize"] and @pa.get_best(@status["iteration"]-1)["output"][0] < h["output"][0])
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

