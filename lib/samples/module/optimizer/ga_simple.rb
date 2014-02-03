require 'json'
require_relative '../OACIS_module.rb'
require_relative 'optimizer.rb'

class GaSimple < Optimizer

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
     "population"=>[], #[{"ps_v"=>{"dt_1"=>0,"dt_2"=>0},"val"=>0}, ..., {"ps_v"=>{"dt_1"=>100,"dt_2"=>100},"val"=>100}]
     "children"=>[]
    }
  end

  def opt_data
    default_number_of_individuals_crossover=(@input_data["population"]/2).to_i
    default_number_of_individuals_mutation=@input_data["population"]-default_number_of_individuals_crossover
    mutation_target_parameters=@input_data["operation"]["settings"]["managed_parameters"].map{|mpara| mpara["key"]}
    {"iteration"=>0,
     "max_optimizer_iteration"=>@input_data["iteration"],
     "population_num"=>@input_data["population"],
     "maximize"=>@input_data["operation"]["settings"]["maximize"],
     "seed"=>@input_data["seed"],
     "type"=>@input_data["operation"]["type"],
     "operation"=>[{"crossover"=>{"count"=>default_number_of_individuals_crossover,"type"=>"1point","selection"=>{"tournament"=>{"tournament_size"=>4}}}},
                   {"mutation"=>{"count"=>default_number_of_individuals_mutation,"type"=>"uniform_distribution","target_parameters"=>mutation_target_parameters}}
                  ],
     "selection"=>"ranking"
    }
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
    generated = []

    optimizer_data["result"].push(template_result)
    if optimizer_data["data"]["iteration"] == 0
      create_children_ga.each_with_index do |child, i|
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
