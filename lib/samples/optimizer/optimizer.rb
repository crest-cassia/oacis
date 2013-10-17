require 'pp'
require 'json'

def target_simulator
  @target_simulator ||= fetch_target_simulator
end

def fetch_target_simulator
  target_simulator = load_target_simulator
  target_simulator
end

def load_target_simulator
  Simulator.find(input_data["target_sim"])
end

def managed_parameter
  parameter_definitions = target_simulator.parameter_definitions
  opt = Simulator.find(input_data["my_id"])
  parameter_definitions.where({"key"=>input_data[]})
  parameter_definitions["dt_1"]["range"]=[-60, 180]
  parameter_definitions["dt_2"]["range"]=[-60, 180]
  parameter_definitions
end

def optimizer_data
  @optimizer_data ||= fetch_optimizer_data
end

def fetch_target_simulator
  optimizer_data = create_optimizer_data
  optimizer_data
end

def create_optimizer_data
  h={}
  h["data"]={"iteration"=>0,
            "max_optimizer_iteration"=>input_data["iteration"],
            "population_num"=>input_data["population"],
            "maximize"=>input_data["maximize"],
            "seed"=>input_data["seed"],
            "ga"=>{"operation"=>[{"crossover"=>{"count"=>32,"type"=>"1point","selection"=>{"tournament"=>{"tournament_size"=>4}}}},{"mutation"=>{"count"=>32,"type"=>"uniform_distribution","range"=>{"dt_1"=>[-10,10],"dt_2"=>[-10,10]}}}],
                   "selection"=>"ranking"
                  }
            }
  h["result"]=[{}]
              {"best"=>{},
               "population"=>[], #[{"ps_v"=>{"dt_1"=>0,"dt_2"=>0},"val"=>0}, ..., {"ps_v"=>{"dt_1"=>100,"dt_2"=>100},"val"=>100}]
               "children"=>[]
              }

  File.open("_output.json", 'w') {|io| io.print h["result"].to_json }
  h
end

def input_data
  @input_data ||= fetch_input_data
end

def fetch_input_data
  input_data = load_input_data
  input_data
end

def load_input_data
  if File.exist?("_input.json")
    io = File.open('_input.json', 'r')
    return JSON.load(io)
  end
end

def get_parents(optimizer_data, count)
  parents = []
  parents_index = []
  case optimizer_data["data"]["ga"]["operation"][0]["crossover"]["selection"].keys.first
  when "tournament"
    begin
      index = []
      while index.length < optimizer_data["data"]["ga"]["operation"][0]["crossover"]["selection"]["tournament"]["tournament_size"] do
        candirate = @prng.rand(optimizer_data["data"]["population_num"])
        index.push(candirate) unless index.include?(candirate)
      end
      parents_index.push(index.min) unless parents_index.include?(index.min) 
    end while parents_index.length < count
  end
  parents_index.each do |i|
    parents.push(optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"][i]["ps_v"])
  end
  parents
end

def n_point_crossover(num_points, parents)
  children = []
  pos =  @prng.rand(managed_parameter.to_a.map {|x| x if x[1].include?("range")}.compact.length-1).truncate + 1
  parents.length.times do |i|
    h = {}
    parents[i].keys.each_with_index do |key, j|
      if j < pos
        h[key] = parents[i][key]
      else
        h[key] = parents[(i-1)%2][key]
      end
    end
    children.push(h)
  end
  children
end

def uniform_distribution_mutation(range, parents)
  children = []
  mpara = managed_parameter
  parents.length.times do |i|
    h = {}
    parents[i].keys.each do |key|
      h[key] = parents[i][key] + @prng.rand(range[key][1] - range[key][0]) + range[key][0]
      h[key] = mpara[key]["range"][0] if h[key] < mpara[key]["range"][0] 
      h[key] = mpara[key]["range"][1] if h[key] > mpara[key]["range"][1] 
    end
    children.push(h)
  end
  children
end

def generate_children_ga(optimizer_data)
  children = []
  optimizer_data["data"]["ga"]["operation"].each do |op|
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
            uniform_distribution_mutation(op["mutation"]["range"],get_parents(optimizer_data, 1)).each do |child|
              children.push(child)
            end
          end
        end
      end
    end
 end
 children
end

def create_children_ga(optimizer_data)
  children = []
  mpara = managed_parameter
  begin
    h = {}
    mpara.each do |key, val|
      if val["range"].present?
        h[key] = @prng.rand(val["range"][1] - val["range"][0]) + val["range"][0]
      end
    end
    children.push(h)
  end while children.length < optimizer_data["data"]["population_num"]
  children
end

def generate_parameters_and_submit_runs(optimizer_data)
  if optimizer_data["data"]["iteration"] == 0
    create_children_ga(optimizer_data).each_with_index do |child, i|
      optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"][i] = {"ps_v"=>child}
    end
  else
    generate_children_ga(optimizer_data).each_with_index do |child, i|
      optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"][i] = {"ps_v"=>child}
    end
  end
  optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].each do |child|
    ps = target_simulator.parameter_sets.build
    ps.v = {}
    managed_parameter.each do |key, val|
      if child["ps_v"][key].present?
        ps.v[key] = child["ps_v"][key]
      else
        ps.v[key] = val["default"]
      end
    end
    if ps.save
      run = ps.runs.build
      run.save
    else
      ps = target_simulator.parameter_sets.where(v: ps.v).first
      if ps.runs.count == 0
        run = ps.runs.build
        run.save
      end
    end
  end
end

def evaluate_results(optimizer_data)
  target_field = "Average_TripTime"
  begin
    optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].each do |child|
      if child["val"].blank?
        h = {}
        managed_parameter.each do |key, val|
          if child["ps_v"][key].present?
            h["v."+key] = child["ps_v"][key]
          else
            h["v."+key] = val["default"]
          end
        end
        ps = target_simulator.parameter_sets.where(h).first
        if ps.runs.first.result.present? and ps.runs.first.result["Vehicle"][target_field].present?
          child["val"] = ps.runs.first.result["Vehicle"][target_field]
        end
      end
      #child["val"] = Math::exp(-((child["ps_v"]["T1"]+10)**2)/10000.0) + Math::exp(-((child["ps_v"]["T2"]-100)**2)/10000.0) + 2.0*Math::exp(-((child["ps_v"]["T1"]-50)**2)/10000.0) + 2.0*Math::exp(-((child["ps_v"]["T2"]-80)**2)/10000.0)
    end
    pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].map{|x| x["val"] if x["val"].present?}.compact.length
    sleep 5
  end while optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"].map{|x| x["val"] if x["val"].present?}.compact.length < optimizer_data["data"]["population_num"]
end

def select_population(optimizer_data)
  case optimizer_data["result"][optimizer_data["data"]["iteration"]]["selection"]
  when "ranking"
    all_members = (optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"] + optimizer_data["result"][optimizer_data["data"]["iteration"]]["children"]).uniq
    if optimizer_data["data"]["maximize"]
      optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"] = all_members.sort{|a, b| (b["val"] <=> a["val"])}[0..optimizer_data["data"]["population_num"]-1]
    else
      optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"] = all_members.sort{|a, b| (a["val"] <=> b["val"])}[0..optimizer_data["data"]["population_num"]-1]
    end
    optimizer_data["result"][optimizer_data["data"]["iteration"]]["best"] = optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"][0]
  end
end

def save_optimizer_data(optimizer_data)
  File.open("_optimizer_data.json", 'w') {|io| io.print optimizer_data.to_json }
end

def optimization_is_finished(optimizer_data)
  if optimizer_data["data"]["iteration"] < optimizer_data["data"]["max_optimizer_iteration"]
    return false
  else
    return true
  end
end

def iterate_run(count)
  if optimizer_data["data"]["seed"].class == Array
    @prng = Random.new.marshal_load(optimizer_data["data"]["seed"])
  else
    @prng = Random.new(optimizer_data["data"]["seed"])
  end
  count.times do |i|
    generate_parameters_and_submit_runs(optimizer_data)
    evaluate_results(optimizer_data)
    select_population(optimizer_data)
    optimizer_data["data"]["iteration"] += 1
    optimizer_data["data"]["seed"] = @prng.marshal_dump
    save_optimizer_data(optimizer_data)
    if optimization_is_finished(optimizer_data)
      break
    end
  end
end


#--Unit tests--
pp input_data
#@prng = Random.new(optimizer_data["data"]["seed"])
#pp target_simulator
#pp managed_parameter
#pp create_children_ga(optimizer_data)
#create_children_ga(optimizer_data).each_with_index do |child, i|
#  optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"][i] = {"ps_v"=>child}
#end
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"].each do |child|
#  pp child
#end
#pp n_point_crossover(1, get_parents(optimizer_data, 2))
#generate_parameters_and_submit_runs(optimizer_data)
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#evaluate_results(optimizer_data)
#pp optimizer_data["result"][optimizer_data["data"]["iteration"]]["population"]
#optimizer_data["data"]["iteration"] += 1
#save_optimizer_data(optimizer_data)
#--Unit tests--

#--Main--
opt_parameter_definitions=nil
if input_data.blank?
  puts "_input.json is missing."
  exit(-1)
end
if target_simulator.blank?
  puts "Target simulator is missing."
  exit(-1)
end
#iterate_run(input_data["iteration"])
#--end --
