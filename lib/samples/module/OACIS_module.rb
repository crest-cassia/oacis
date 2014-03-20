require 'json'
require_relative 'OACIS_module_base.rb'
require_relative 'OACIS_module_data.rb'

class OacisModule

  def initialize(_input_data)
    _input_data.keys.each do |key|
      _input_data[key] = JSON.parse(_input_data[key]) if JSON.is_json?(_input_data[key]) # Array or Hash data is stored with json format
    end
    @input_data = _input_data
    raise "Target simulator is missing." if target_simulator.blank?
    create_or_restore_module_data
  end

  def create_or_restore_module_data
    module_data.data["_input_data"]=@input_data
    module_data.data["_status"]={}
    if File.exists?("_output.json")
      module_data.set_data(JSON.load(File.open("_output.json")))
      @num_iterations = module_data.data["_status"]["iteration"]
    else
      module_data.data["_status"]["iteration"] = 0
      @num_iterations = 0
    end
  end

  def self.paramater_definitions(sim, v)
    raise "val is not a Hash" unless v.is_a?(Hash)
    a = []
    v.each do |key, val|
      pd = sim.parameter_definitions.build
      pd["key"] = key
      default_val = val
      default_val = val.to_json if val.is_a?(Hash) or val.is_a?(Array)
      pd["default"] = default_val
      parameter_type = "Integer" if val.is_a?(Integer)
      parameter_type = "Float" if val.is_a?(Float)
      parameter_type = "Boolean" if val.is_a?(TrueClass) or val.is_a?(FalseClass)
      parameter_type = "String" if val.is_a?(String) or val.is_a?(Hash) or val.is_a?(Array)
      pd["type"] = parameter_type
      a << pd
    end
    a
  end

  private
  #override
  def generate_runs
    generate_runs_iteration(@num_iterations)
  end

  #override
  def evaluate_runs
    evaluate_runs_iteration(@num_iterations)
  end

  #override
  def dump_serialized_data
    module_data.data["_status"]["iteration"]=@num_iterations
    output_file = "_output.json"
    File.open(output_file, 'w') {|io| io.print module_data.data.to_json }
  end

  #override
  def finished?
    raise "IMPLEMENT ME"
  end

  def target_simulator
    @target_simulator ||= Simulator.find(@input_data["_target"]["Simulator"])
  end

  def target_analyzer
    @target_analyzer ||= Analyzer.find(@input_data["_target"]["Analyzer"]) if @input_data["_target"]["Analyzer"]
  end

  def target_runs_count
    @target_runs_count ||= @input_data["_target"]["RunsCount"]
  end

  def target_host
    @target_host ||= Host.in(id: @target_simulator.executable_on_ids).order_by(max_num_jobs: "desc").first
  end
 
  def get_target_fields(result)
    # when you want to get ps.runs.first.result["result"][0]
    # return result.try(:fetch, "result").try(:slice, 0)
    raise "IMPLEMENT ME"
  end

  def target_collections
    if target_analyzer
      Analysis.where(analyzer_id: target_analyzer.to_param, status: :finished).in(parameter_set_id: @ps_archive).only(:result, :parameter_set)
    else
      Run.where(status: :finished).in(parameter_set_id: @ps_archive).only(:result, :parameter_set)
    end
  end

  def target_results
    target_collections.map {|col| {col.parameter_set_id => get_target_fields(col.result)}}
  end

  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions.order_by(:id.asc).map{|pd|
      @input_data["_managed_parameters"].each do |mp|
        pd["range"]=mp["range"].dup if pd["key"] == mp["key"]
      end
      pd
    }
    parameter_definitions
  end

  def managed_parameters_table
    a = []
    managed_parameters.each do |mpara|
      if mpara["range"].present?
        h = {"key"=>mpara["key"],"type"=>mpara["type"], "range"=>mpara["range"]}
        h["range"].map! {|x| x.to_f} if h["type"] == "Float"
        h["range"].map! {|x| x.to_i} if h["type"] == "Integer"
        a << h
      end
    end
    a
  end

  def adjust_range_with_maneged_parameters(x, d)
    mpara = managed_parameters.select{|mp| mp["key"] == managed_parameters_table[d]["key"]}.first
    case mpara["type"]
    when "Integer"
      x = mpara["range"][0] if x < mpara["range"][0]
      x = mpara["range"][1] if x > mpara["range"][1]
      if mpara["range"].length ==3 and mpara["range"][2] != 0
        range = mpara["range"][2]
        x = (Rational((x * 1/range).to_i,1/range)).to_i
      end
    when "Float"
      x = mpara["range"][0] if x < mpara["range"][0]
      x = mpara["range"][1] if x > mpara["range"][1]
      if mpara["range"].length ==3 and mpara["range"][2] != 0
        range = mpara["range"][2]
        x = ((Rational((x * 1/range).to_i,1/range)).to_f).round(6)
      end
    end
    x
  end

  # this data is written in _output.json and imported to DB
  def module_data
    @module_data ||= create_module_data
  end

  def create_module_data
    OacisModuleData.new
  end

  def generate_runs_iteration(iteration)
    generated = []
    @ps_archive = []

    raise "No generated runs in iteration #{@num_iterations}" if module_data.data["data_sets"][iteration].length == 0

    #adjust range of parameters
    module_data.data["data_sets"][iteration].each_with_index do |data, i|
      data["input"].map!.with_index {|x, d| adjust_range_with_maneged_parameters(x, d)}
      module_data.set_datasets(iteration, i, data)
    end

    mp_table_keys = managed_parameters_table.map{|m| m["key"]}
    module_data.data["data_sets"][iteration].map{|d| d["input"]}.each do |input|
      v = {}
      managed_parameters.each do |mpara|
        index = mp_table_keys.index(mpara["key"])
        if index
          v[mpara["key"]] = input[index]
        else
          v[mpara["key"]] = mpara["default"]
        end
      end
      ps = target_simulator.parameter_sets.find_or_create_by(v: v)
      @ps_archive << ps.id
      if ps.runs.count < target_runs_count
        (target_runs_count - ps.runs.count).times do
          run = ps.runs.build
          run.submitted_to_id=target_host
          run.save
          generated << run
        end
      end
    end
    generated
  end

  def evaluate_runs_iteration(iteration)
    data_sets = module_data.data["data_sets"][iteration]
    results = {}
    target_results.each do |target_result|
      target_result.each_pair do |ps_id, result_val|
        results[ps_id] = results[ps_id].to_a << result_val
      end
    end
    data_sets.each_with_index do |data, i|
      data["output"] = results[@ps_archive[i]]
    end
  end
end

