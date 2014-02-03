require 'json'
require_relative '../OACIS_module.rb'

class Optimizer < OacisModule

  @@OPTIMIZER_TYPES = []

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
    evaluate_results
    select_population
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

  def get_parents(optimizer_data, count)
    parents = []
    parents_index = []
    case optimizer_data["data"]["operation"][0]["crossover"]["selection"].keys.first
    when "tournament"
      begin
        index = []
        while index.length < optimizer_data["data"]["operation"][0]["crossover"]["selection"]["tournament"]["tournament_size"] do
          candirate = @prng.rand(optimizer_data["data"]["population_num"])
          index.push(candirate) unless index.include?(candirate)
        end
        parents_index.push(index.min) unless parents_index.include?(index.min) 
      end while parents_index.length < count
    end
    parents_index.each do |i|
      parents.push(optimizer_data["result"][optimizer_data["data"]["iteration"]-1]["population"][i]["ps_v"])
    end
    parents
  end

  def n_point_crossover(num_points, parents)
    children = []
    pos =  @prng.rand(managed_parameters.map {|x| x if x["range"].present?}.compact.length-1).truncate + 1
    parents.length.times do |i|
      h = {}
      parents[i].keys.each_with_index do |key, j|
        if j < pos
          h[key] = parents[i][key]
        else
          h[key] = parents[(i-1)%2][key]
        end
      end
      puts "operation:n_point_crossover,iteration:"+optimizer_data["data"]["iteration"].to_s+",parents:["+parents[i].to_s+","+parents[(i-1)%2].to_s+"],childlen:["+h.to_s+"]"
      children.push(h)
    end
    children
  end

  def uniform_distribution_mutation(parents)
    children = []
    parents.length.times do |i|
      h = {}
      mutation = optimizer_data["data"]["operation"].map{|op| op["mutation"] if op["mutation"].present? and op["mutation"]["type"]=="uniform_distribution"}.compact.first
      mutation["target_parameters"].each do |key|
        mpara = managed_parameters.where({key: key}).first
        unless mpara["type"] == "Integer" or mpara["type"] == "Float"
          STDERR.puts mpara["type"].to_s+" is not supported in uniform_distribution_mutation."
          exit(-1)
        end

        mutation_range = []
        if mpara["range"].length ==3
          mutation_range.push(mpara["range"][2]*(-3)) #min
          mutation_range.push(mpara["range"][2]*(3)) #max

          h[key] = parents[i][key] + @prng.rand(mutation_range[1] - mutation_range[0]) + mutation_range[0]
          h[key] = mpara["range"][0] if h[key] < mpara["range"][0]
          h[key] = mpara["range"][1] if h[key] > mpara["range"][1]

          case mpara["type"]
          when "Integer"
            h[key] = (Rational((h[key] * 1/mpara["range"][2]).to_i,1/mpara["range"][2])).to_i
          when "Float"
            h[key] = ((Rational((h[key] * 1/mpara["range"][2]).to_i,1/mpara["range"][2])).to_f).round(6)
          end
        else
          search_range=mpara["range"][1]-mpara["range"][0]
          mutation_range.push(search_range*(-0.05)) #min
          mutation_range.push(search_range*(-0.05)) #max

          h[key] = parents[i][key] + @prng.rand(mutation_range[key][1] - mutation_range[0]) + mutation_range[0]
          h[key] = mpara["range"][0] if h[key] < mpara["range"][0]
          h[key] = mpara["range"][1] if h[key] > mpara["range"][1]

          case mpara["type"]
          when "Integer"
            h[key] = h[key].to_i
          when "Float"
            h[key] = h[key].to_f
          end
        end
      end
      puts "operation:uniform_distribution_mutation,iteration:"+optimizer_data["data"]["iteration"].to_s+",parents:["+parents[i].to_s+"],childlen:["+h.to_s+"]"
      children.push(h)
    end
    children
  end

  def generate_children_ga
    children = []
    optimizer_data["data"]["operation"].each do |op|
      op.keys.each do |key|
        case key
        when "crossover"
          case op["crossover"]["type"]
          when "1point"
            op_children=[]
            while op_children.length <= op["crossover"]["count"]
              n_point_crossover(1, get_parents(optimizer_data, 2)).each do |child|
                op_children.push(child)
              end
            end
            children+=op_children[0..op["crossover"]["count"]-1]
          else
            STDERR.puts op["crossover"]["type"].to_s+" is not defined in crossover operations."
            exit(-1)
          end
        when "mutation"
          case op["mutation"]["type"]
          when "uniform_distribution"
            op_children=[]
            while op_children.length <= op["mutation"]["count"]
              uniform_distribution_mutation(get_parents(optimizer_data, 1)).each do |child|
                op_children.push(child)
              end
            end
            children+=op_children[0..op["mutation"]["count"]-1]
          else
            STDERR.puts op["mutation"]["type"].to_s+" is not defined in mutation operations."
            exit(-1)
          end
        else
          STDERR.puts key.to_s+" is not defined as operations."
          exit(-1)
        end
      end
    end
    children
  end

  def create_children_ga
    children = []
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
      children.push(h)
    end while children.length < optimizer_data["data"]["population_num"]
    children
  end

  def generate_parameters_and_submit_runs
    raise "IMPLEMENT ME"
  end

  def evaluate_results
    raise "IMPLEMENT ME"
  end
end
