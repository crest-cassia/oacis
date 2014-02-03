require 'json'
require_relative '../OACIS_module.rb'
require_relative 'optimizer.rb'

class Pso < Optimizer

  def self.definitions(sim, anz, host, type, managed_params)
    a = []
    a.push(ParameterDefinition.new({"key"=>"target", "type"=>"String", "default" => {"Simulator"=>sim.to_param,"Analyzer"=>anz.to_param,"Host"=>host.map{|h| h.to_param}}.to_json.to_s, "description" => "targets for operation"}))
    h = {"module"=>"optimization","type"=>type,"settings"=>{"maximize"=>true}}
    h["settings"]["managed_parameters"]=[]
    managed_params.each do |mpara|
      h["settings"]["managed_parameters"].push(mpara)
    end
    a.push(ParameterDefinition.new({"key"=>"operation", "type"=>"String", "default" => h.to_json.to_s, "description" => type}))
    a.push(ParameterDefinition.new({"key"=>"iteration", "type"=>"Integer", "default" => 2, "description" =>"max iteration"}))
    a.push(ParameterDefinition.new({"key"=>"population_num", "type"=>"Integer", "default" => 32, "description" =>"num of particles"}))
    a.push(ParameterDefinition.new({"key"=>"w", "type"=>"Float", "default" => 0.729, "description" =>"inertia weight"}))
    a.push(ParameterDefinition.new({"key"=>"cp", "type"=>"Float", "default" => 1.494, "description" =>"coefficient parameter for personal best attraction"}))
    a.push(ParameterDefinition.new({"key"=>"cg", "type"=>"Float", "default" => 1.494, "description" =>"coefficient parameter for global best attraction"}))
    a.push(ParameterDefinition.new({"key"=>"seed", "type"=>"Integer", "default" => 0, "description" =>"seed for an optimizer"}))
    a
  end

  def initialize(data)
    super(data)
  end

  private
  #override
  def generate_runs
    generate_parameters_and_submit_runs
  end

  #override
  def evaluate_runs
    evaluate_results
  end

  #override
  def finished?
    b=[]
    b.push(super)
    return b.any?
  end

  def create_optimizer_data
    h={}
    h["data"]=opt_data
    h["result"]=[]
    File.open("_output.json", 'w') {|io| io.print h["result"].to_json }
    h
  end

  def template_result
    {"best"=>{},
     "particle_position"=>[], #[{"ps_v"=>{"dt_1"=>0,"dt_2"=>0},"val"=>0}, ..., {"ps_v"=>{"dt_1"=>100,"dt_2"=>100},"val"=>100}]
     "particle_velocity"=>[]
     "personal_best"=>[]
    }
  end

  def opt_data
    default_number_of_individuals_crossover=(@input_data["population"]/2).to_i
    default_number_of_individuals_mutation=@input_data["population"]-default_number_of_individuals_crossover
    mutation_target_parameters=@input_data["operation"]["settings"]["managed_parameters"].map{|mpara| mpara["key"]}
    {"iteration"=>0,
     "max_optimizer_iteration"=>@input_data["iteration"],
     "particles_num"=>@input_data["particles_num"],
     "maximize"=>@input_data["operation"]["settings"]["maximize"],
     "seed"=>@input_data["seed"],
     "type"=>@input_data["operation"]["type"],
     "operation"=>[{"crossover"=>{"count"=>default_number_of_individuals_crossover,"type"=>"1point","selection"=>{"tournament"=>{"tournament_size"=>4}}}},
                   {"mutation"=>{"count"=>default_number_of_individuals_mutation,"type"=>"uniform_distribution","target_parameters"=>mutation_target_parameters}}
                  ],
     "selection"=>"ranking"
    }
  end

  def create_particles
    particles = []
    mpara = managed_parameters
    begin
      h = {}
      mpara.each do |val|
        if val["range"].present?
          case val["type"]
          when "Integer"
            if val["range"].length == 3 and val["range"][2] != 0
              h[val["key"]] = (Rational((@prng.rand((val["range"][1] - val["range"][0]).to_i) * 1/val["range"][2]).to_i,1/val["range"][2])).to_i + val["range"][0].to_i
            else
              h[val["key"]] = @prng.rand((val["range"][1] - val["range"][0]).to_i) + val["range"][0].to_i
            end
          when "Float"
            if val["range"].length == 3 and val["range"][2] != 0
              h[val["key"]] = ((Rational((@prng.rand((val["range"][1] - val["range"][0]).to_f) * 1.0/val["range"][2]).to_i,1.0/val["range"][2])).to_f + val["range"][0].to_f).round(6)
            else
              h[val["key"]] = @prng.rand((val["range"][1] - val["range"][0]).to_f) + val["range"][0].to_f
            end
          when "String"
            h[val["key"]] = val["range"][@prng.rand(val["range"].length)]
          when "Boolean"
            h[val["key"]] = val["range"][@prng.rand(val["range"].length)]
          end
        end
      end
      particles.push(h)
    end while particles.length < optimizer_data["data"]["population_num"]
    particles
  end

  def move_particles
    particles = []
    velocities = []
    mpara = managed_parameters
    optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["particle_position"].each_with_index do |ps_v, i|
    begin
      h = {}
      v = {}
      mpara.each do |val|
        if val["range"].present?
          case val["type"]
          when "Integer"
            if val["range"].length == 3 and val["range"][2] != 0
              h[val["key"]] = (Rational((@prng.rand((val["range"][1] - val["range"][0]).to_i) * 1/val["range"][2]).to_i,1/val["range"][2])).to_i + val["range"][0].to_i
            else
              v[val["key"]] = @input_data["w"]*optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["particle_velocity"][i]
              v[val["key"]] += @input_data["cp"]*(optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["personal_best"][i][val["key"]] - ps_v[val["key"]])
              v[val["key"]] += @input_data["cg"]*(optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["best"][val["key"]] - ps_v[val["key"]])
              h[val["key"]] = ps_v[val["key"]]+v[val["key"]].to_i
            end
          when "Float"
            if val["range"].length == 3 and val["range"][2] != 0
              h[val["key"]] = ((Rational((@prng.rand((val["range"][1] - val["range"][0]).to_f) * 1.0/val["range"][2]).to_i,1.0/val["range"][2])).to_f + val["range"][0].to_f).round(6)
            else
              h[val["key"]] = @prng.rand((val["range"][1] - val["range"][0]).to_f) + val["range"][0].to_f
            end
          when "String"
            h[val["key"]] = val["range"][@prng.rand(val["range"].length)]
          when "Boolean"
            h[val["key"]] = val["range"][@prng.rand(val["range"].length)]
          end
        end
      end
      particles.push(h)
      velocities.push(v)
    end
    particles
  end

  def generate_parameters_and_submit_runs
    generated = []

    optimizer_data["result"].push(template_result)
    if optimizer_data["data"]["iteration"] == 0
      create_particles.each_with_index do |child, i|
        optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"][i] = {"ps_v"=>child}
      end
    else
      generate_children_ga.each_with_index do |child, i|
        optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"][i] = {"ps_v"=>child}
      end
    end
    optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].each do |child|
      v = {}
      managed_parameters.each do |val|
        if child["ps_v"][val["key"]].present?
          v[val["key"]] = child["ps_v"][val["key"]]
        else
          v[val["key"]] = val["default"]
        end
      end
      ps = target_simulator.parameter_sets.find_or_create_by(v: v)
      if ps.runs.count == 0
        run = ps.runs.build
        run.submitted_to_id=@input_data["target"]["Host"].first
        run.save
        generated << run
      end
    end
    generated
  end

  def target_field(ps)
    anl = Analysis.where(analyzer_id: target_analzer.to_param, analyzable_id: ps.runs.first.to_param, status: :finished).first
    b = anl
    return nil if b.blank?
    b = b.result
    return nil if b.blank?
    b = b["Fitness"]
    return nil if b.blank?
    b
  end

  def evaluate_results
    get_values
    select_population
  end

  def get_values
    target_field = "Fitness"

    optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].each do |child|
      if child["val"].blank?
        h = {}
        managed_parameters.each do |val|
          if child["ps_v"][val["key"]].present?
            h["v."+val["key"]] = child["ps_v"][val["key"]]
          else
            h["v."+val["key"]] = val["default"]
          end
        end
        ps = target_simulator.parameter_sets.where(h).first
        val = target_field(ps)
        if val.present?
          child["val"] = val
        end
      end
    end
    finished_run_count = optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].select{|x| x["val"].present?}.length
    puts "finished_run_count:#{finished_run_count}"
    raise "error in __method__" if finished_run_count != optimizer_data["data"]["population_num"]
  end

  def select_population
    case optimizer_data["data"]["selection"]
    when "ranking"
      if optimizer_data["data"]["iteration"]==0
        all_members = optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"]
      else
        all_members = (optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["population"] + optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"]).uniq
      end
      if optimizer_data["data"]["maximize"]
        optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"] = all_members.sort{|a, b| (b["val"] <=> a["val"])}[0..optimizer_data["data"]["population_num"]-1]
      else
        optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"] = all_members.sort{|a, b| (a["val"] <=> b["val"])}[0..optimizer_data["data"]["population_num"]-1]
      end
      optimizer_data["result"][optimizer_data["data"]["iteration"]]["best"] = optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"][0]
    end
  end
end

