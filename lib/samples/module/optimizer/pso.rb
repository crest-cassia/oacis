require 'json'
require_relative 'optimizer_data.rb'

class Pso

  def self.fitnessfunction(a)
    [a.inject{|sum, n| sum + n*n }]
  end

  def self.fitnessfunction_definition
    h={}
    h["dimension"]=10
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
    h["iteration"]=2
    h["population"]=10
    h["w"]=[0.729,0.729]
    h["cp"]=1.494
    h["cg"]=1.494
    h["seed"]=0
    h["maximize"]=false
    h
  end

  def initialize()
    @prng = Random.new(definition["seed"])
    @pa = ParticleArchve.new
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
    end while (!finished?)
  end

  private
  def dump_serialized_data
    h={}
    h["data"]=opt_data
    @status["iteration"]=@num_iterations
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
    b.push(super)
    return b.any?
  end

  def adjust_range(x, d)
    if fitnessfunction_definition["range"][d].length ==3 and fitnessfunction_definition["range"][d][2] != 0
      case fitnessfunction_definition["type"][d]
      when "Integer"
        x = (Rational((x * 1/fitnessfunction_definition["range"][d][2]).to_i,1/fitnessfunction_definition["range"][d][2])).to_i
      when "Float"
        x = ((Rational((x * 1/fitnessfunction_definition["range"][d][2]).to_i,1/fitnessfunction_definition["range"][d][2])).to_f).round(6)
      end
    end
  end

  def create_particles
    definition["population"].times do |i|
      fitnessfunction_definition["dimension"].times do |d|
        x = @prng.rand(fitnessfunction_definition["range"][d][1] - fitnessfunction_definition["range"][d][0]) + fitnessfunction_definition["range"][d][0]
        x = fitnessfunction_definition["range"][d][0] if x < fitnessfunction_definition["range"][d][0]
        x = fitnessfunction_definition["range"][d][1] if x > fitnessfunction_definition["range"][d][1]
        adjust_range(x, d)
        @pa.set_position(@iteration, i, d, x)
        @pa.set_velocity(@iteration, i, d, 0.0)
      end
    end
  end

  def move_particles
    definition["population"].times do |i|
      fitnessfunction_definition["dimension"].times do |d|
        w = (definition["w"][0] - definition["w"][1])*(1.0-@iteration.to_f/definition["iteration"].to_f) + definition["w"][1]
        v = w*@pa.get_velocity(@iteration, i, d)
        v += definition["cp"]*@prng.rand(1.0)*(@pa.get_pbest_position(@iteration, i, d) - @pa.get_position(@iteration, i, d))
        v += definition["cg"]*@prng.rand(1.0)*(@pa.get_best_position(@iteration, i, d) - @pa.get_position(@iteration, i, d))
        x = @pa.get_position(@iteration, i, d)
        adjust_range(x, d)
        @pa.set_position(@iteration, i, d, x)
        @pa.set_velocity(@iteration, i, d, v)
      end
    end
  end

  def evaluate_particles
    definition["population"].times do |i|
      @pa.set_fitness(@iteration, i, [fitnessfunction(@pa.get_positions(@iteration, i))] )
    end
  end
end

class ParticleArchive < OptimizerData

  def data
    h = super
    h["velocity"] = []
    h["personal_best"] = []
    h
  end

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
    result["velocity"][iteration][dim]
  end

  def set_velocity(iteration, index, dim, val)
    a = get_velocities(iteration, index)
    a[dim] = val
  end

  def get_pbest(iteration, index)
    result["personal_best"][iteration] = [] if result["personal_best"][iteration].nil?
    result["personal_best"][iteration][index] ||= []
  end

  def set_pbest(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_pbest(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end

  def get_pbest_position(iteration, index, dim)
    result["personal_best"][iteration] = [] if result["personal_best"][iteration].nil?
    result["personal_best"][iteration][index] = {"input"=>[], "output"=>[], "velocity"=>} if result["personal_best"][iteration][index].nil?
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

