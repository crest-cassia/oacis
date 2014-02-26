require 'json'
require_relative 'OACIS_module_base.rb'
require_relative 'OACIS_module_data.rb'

class OacisModule

  def initialize(data)
    @input_data = data
    raise "Target simulator is missing." if target_simulator.blank?
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
    raise "IMPLEMENT ME"
  end

  #override
  def evaluate_runs
    raise "IMPLEMENT ME"
  end

  #override
  def dump_serialized_data
    output_file = "_output.json"
    File.open(output_file, 'w') {|io| io.print oacis_module_data.to_json }
  end

  #override
  def finished?
    raise "IMPLEMENT ME"
  end

  def target_simulator
    @target_simulator ||= Simulator.find(@input_data["_target"]["Simulator"])
  end

  def target_analyzer
    @target_analyzer ||= Analyzer.find(@input_data["_target"]["Analyzer"])
  end

  def target_host
    @target_host ||= Host.find(@input_data["_target"]["Host"].first)
  end
 
  def get_target_fields(result)
    raise "IMPLEMENT ME" # [result.try(:fetch, "Fitness")]
  end

  def managed_parameters
    parameter_definitions = target_simulator.parameter_definitions.order_by(:id.asc).map{|pd|
      @input_data["_managed_parameters"].each do |mp|
        pd["range"]=mp["range"] if pd["key"] == mp["key"]
      end
      pd
    }
    parameter_definitions
  end

  def managed_parameters_table
    a = []
    managed_parameters.each do |mpara|
      if mpara["range"].present?
        a << {"key"=>mpara["key"],"type"=>mpara["type"], "range"=>mpara["range"]}
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

  #for dump and restart
  def oacis_module_data
    @oacis_module_data ||= create_oacis_module_data
  end

  def create_module_data
    OacisModuleData.new
  end

  def generate_runs(iteration)
    generated = []
    @ps_archive = []

    #adjust range of parameters
    oacis_module_data.data["data_sets"][iteration].each_with_index do |data, i|
      data["input"].map!.with_index {|x, d| adjust_range_with_maneged_parameters(x, d)}
      oacis_module_data.set_datasets(iteration, i, data)
    end

    mp_table_keys = managed_parameters_table.map{|m| m["key"]}
    oacis_module_data.data["data_sets"][iteration].map{|d| d["input"]}.each do |input|
      v = {}
      managed_parameters.each do |mpara|
        index = mp_table_keys.index(mpara["key"])
        if index
          v[mpara["key"]] = input[index]
        else
          v[mpara["key"]] = mpara["default"]
        end
      end
      ps = target_simulator.parameter_sets.only(:runs).hint(v: 1).find_or_create_by(v: v)
      @ps_archive << ps.id
      if ps.runs.count == 0
        run = ps.runs.build
        run.submitted_to_id=target_host
        run.save
        generated << run
      end
    end
    generated
  end

  def evaluate_runs(iteration)
    data_sets = oacis_module_data.data["data_sets"][iteration]
    results = Analysis.where(analyzer_id: target_analyzer.to_param, status: :finished).in(parameter_set_id: @ps_archive).only(:result, :parameter_set)
              .map {|anl| {anl.parameter_set_id => get_target_fields(anl.result)}}.inject({}) {|h, a| h.merge!(a)}

    data_sets.each_with_index do |data, i|
      data["output"] = results[@ps_archive[i]]
    end
  end
end

