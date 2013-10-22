require 'pp'
require 'json'

class Optimizer
  def initialize(data)
    @input_data = data
  end

  def run
    if target_simulator.blank?
      puts "Target simulator is missing."
      exit(-1)
    end
    iterate_run(optimizer_data["data"]["max_optimizer_iteration"])
  end

  private
  def target_simulator
    @target_simulator ||= fetch_target_simulator
  end

  def fetch_target_simulator
    target_simulator = load_target_simulator
    target_simulator
  end

  def load_target_simulator
    Simulator.find(@input_data["target"]["Simulator"])
  end

  def target_analzer
    @target_analyzer ||= fetch_target_analyzer
  end

  def fetch_target_analyzer
    target_analyser = load_target_analyzer
    target_analyser
  end

  def load_target_analyzer
    Analyzer.find(@input_data["target"]["Analyzer"])
  end

  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions
    @input_data["operation"]["settings"]["managed_parameters"].each do |mpara|
      parameter_definitions.where({"key"=>mpara["key"]}).first["range"]=mpara["range"]
    end
    parameter_definitions
  end

  def optimizer_data
    @optimizer_data ||= fetch_optimizer_data
  end

  def fetch_optimizer_data
    optimizer_data = create_optimizer_data
    optimizer_data
  end

  def create_optimizer_data
    h={}
    h["data"]={"iteration"=>0,
              "max_optimizer_iteration"=>@input_data["iteration"],
              "population_num"=>@input_data["population"],
              "maximize"=>@input_data["operation"]["settings"]["maximize"],
              "seed"=>@input_data["seed"],
              "type"=>"GA",
              "operation"=>[{"crossover"=>{"count"=>(@input_data["population"]/2).to_i,"type"=>"1point","selection"=>{"tournament"=>{"tournament_size"=>4}}}},
                            {"mutation"=>{"count"=>@input_data["population"]-(@input_data["population"]/2).to_i,"type"=>"uniform_distribution","target_parameters"=>["p1","p2"]}}
                           ],
               "selection"=>"ranking"
              }
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
          puts mpara["type"].to_s+" is not supported in uniform_distribution_mutation."
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
          (op["crossover"]["count"]/2).times do |i|
            case op["crossover"]["type"]
            when "1point"
              n_point_crossover(1, get_parents(optimizer_data, 2)).each do |child|
                children.push(child)
              end
            end
          end
        when "mutation"
          op["mutation"]["count"].times do |i|
            case op["mutation"]["type"]
            when "uniform_distribution"
              uniform_distribution_mutation(get_parents(optimizer_data, 1)).each do |child|
                children.push(child)
              end
            end
          end
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
      ps = target_simulator.parameter_sets.build
      ps.v = {}
      managed_parameters.each do |val|
        if child["ps_v"][val["key"]].present?
          ps.v[val["key"]] = child["ps_v"][val["key"]]
        else
          ps.v[val["key"]] = val["default"]
        end
      end
      pp ps
      if ps.save
        run = ps.runs.build
        run.submitted_to_id=@input_data["target"]["Host"].first
        run.save
      else
        #if this parameter set has been saved in OACIS, optimizer tries to make one run on the parameter set.
        ps = target_simulator.parameter_sets.where(v: ps.v).first
        if ps.runs.count == 0
          run = ps.runs.build
          run.submitted_to_id=@input_data["target"]["Host"].first
          run.save
        end
      end
    end
  end

  def target_field(ps)
    b = ps.runs.first
    return nil if b.blank?
    b = b.analyses
    return nil if b.blank?
    b = b.where(analyzer_id: target_analzer.to_param).last
    return nil if b.blank?
    b = b.result
    return nil if b.blank?
    b = b["Fitness"]
    return nil if b.blank?
    b
  end

  def evaluate_results
    target_field = "Fitness"
    begin
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
      pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].map{|x| x["val"] if x["val"].present?}.compact.length
      sleep 5
    end while optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].map{|x| x["val"] if x["val"].present?}.compact.length < optimizer_data["data"]["population_num"]
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

  def save_optimizer_data
    File.open("_output.json", 'w') {|io| io.print optimizer_data.to_json }
  end

  def optimization_is_finished
    b=[]
    b.push(optimizer_data["data"]["iteration"] > optimizer_data["data"]["max_optimizer_iteration"])
    return b.any?
  end

  def iterate_run(count)
    if optimizer_data["data"]["seed"].class == String
      @prng = Random.new.marshal_load(JSON.parse(optimizer_data["data"]["seed"]))
    else
      @prng = Random.new(optimizer_data["data"]["seed"])
    end
    count.times do |i|
      puts "iteration:"+optimizer_data["data"]["iteration"].to_s
      generate_parameters_and_submit_runs
      evaluate_results
      select_population
      optimizer_data["data"]["seed"] = @prng.marshal_dump.to_json
      save_optimizer_data
      optimizer_data["data"]["iteration"] += 1
      if optimization_is_finished
        break
      end
    end
  end
end

#--Unit tests--
#_input="{\"target\":\"{\\\"Simulator\\\":\\\"526224564e59813f40000001\\\",\\\"Analyzer\\\":\\\"526224564e59813f40000004\\\",\\\"Host\\\":[\\\"526224e24e5981050c000001\\\"]}\",\"operation\":\"{\\\"module\\\":\\\"optimization\\\",\\\"type\\\":\\\"GA\\\",\\\"settings\\\":{\\\"iteration\\\":2,\\\"population\\\":32,\\\"maximize\\\":true,\\\"seed\\\":0,\\\"managed_parameters\\\":[{\\\"key\\\":\\\"p1\\\",\\\"type\\\":\\\"Float\\\",\\\"default\\\":0.0,\\\"descritption\\\":null,\\\"range\\\":[-5.0,5.0,0.1]},{\\\"key\\\":\\\"p2\\\",\\\"type\\\":\\\"Float\\\",\\\"default\\\":0.0,\\\"descritption\\\":null,\\\"range\\\":[-5.0,5.0,0.1]}]}}\",\"_seed\":1348280022}"
#input_data=JSON.parse(_input) #input_data={"target"=>"{\"Simulator\":\"526224564e59813f40000001\",\"Analyzer\":\"526224564e59813f40000004\",\"Host\":[\"526224e24e5981050c000001\"]}", "operation"=>"{\"module\":\"optimization\",\"type\":\"GA\",\"settings\":{\"iteration\":2,\"population\":32,\"maximize\":true,\"seed\":0,\"managed_parameters\":[{\"key\":\"p1\",\"type\":\"Float\",\"default\":0.0,\"descritption\":null,\"range\":[-5.0,5.0,0.1]},{\"key\":\"p2\",\"type\":\"Float\",\"default\":0.0,\"descritption\":null,\"range\":[-5.0,5.0,0.1]}]}}", "_seed"=>1348280022}
#opt = Optimizer.new(input_data)
#pp input_data
#@prng = Random.new(input_data["operation"]["settings"]["seed"])
#pp target_simulator
#pp managed_parameters
#pp create_children_ga(optimizer_data)
#optimizer_data["result"].push(template_result)
#create_children_ga(optimizer_data).each_with_index do |child, i|
#  optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"][i] = {"ps_v"=>child}
#end
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#pp n_point_crossover(1, get_parents(optimizer_data, 2))
#generate_parameters_and_submit_runs(optimizer_data)
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#evaluate_results(optimizer_data)
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#optimizer_data["data"]["iteration"] += 1
#save_optimizer_data(optimizer_data)
#--Unit tests--
