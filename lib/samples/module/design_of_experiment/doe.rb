require 'json'
require_relative '../OACIS_module.rb'
require_relative '../OACIS_module_data.rb'
require_relative 'f_test.rb'
require_relative 'orthogonal_array'

class Doe < OacisModule

  def self.definition
    h = {}
    h["ps_count_max"] = 80
    h["range_count_max"] = 30
    h["f_value_threshold"] = 10.0
    h["target_field"] = "order_parameter"
    h
  end

  #NUM_RUNS = 5

  def initialize(input_data)
    super(input_data)
    #@sim = Simulator.where(name: "dilemma_game").first
    #raise "Simulator 'dilemma_game' is not found" unless @sim
    #@host = Host.where(name: "localhost").first
    #raise "Host 'localhost' is not found" unless @host

    @param_names = managed_parameters_table.map {|mpt| mpt["key"]}

    #noise_array = [0, 0.05]
    #num_games_array = [10, 100]

    #if input_data
    #  noise_array = input_data[@param_names[0]]
    #  num_games_array = input_data[@param_names[1]]
    #end

    @ranges_count = 0

    #@range_hashes = [ {@param_names[0] => noise_array, @param_names[1] => num_games_array} ]
    @range_hashes = [{}]
    managed_parameters_table.each do |pd|
      @range_hashes[0][pd["key"]] = pd["range"]
    end
  end

  def generate_runs
    #created_runs = []
    pp @range_hashes
    ps_count = 0
    @range_hashes.each do |range_hash|
      get_parameter_sets_from_range_hash(range_hash).each do |ps|
        module_data.set_input(@num_iterations, ps_count, ps)
        ps_count += 1
      end
    end
    #created_runs

    super
  end

  private
  def get_parameter_sets_from_range_hash(range_hash)
    @parameter_sets = []

    oa_param = @param_names.map do |name|
      {name: name, paramDefs: [0, 1]}
    end
    @orthogonal_array = OrthogonalArray.new(oa_param)

    @orthogonal_array.table.transpose.each do |row|
      @parameter_hash = {}
      @param_names.each_with_index do |name, idx|
        range = range_hash[name]
        parameter_value = range[ row[idx].to_i ]
        @parameter_hash[name] = parameter_value
      end
      #parameter_sets << get_parameter_set(parameter_hash)
      @parameter_sets << managed_parameters_table.map {|mpt| @parameter_hash[mpt["key"]]}
    end

    @parameter_sets
  end

  #def get_parameter_set(parameter_hash)
  #  h = {}
  #  parameter_hash.each {|key,val| h["v.#{key}"] = val }
  #  ps = @sim.parameter_sets.where(h).first
  #  unless ps
  #    ps = @sim.parameter_sets.build({"v" => parameter_hash})
  #    ps.save!
  #  end
  #  ps
  #end

  def create_runs_for(parameter_set)
    created_runs = []
    (NUM_RUNS - parameter_set.runs.count).times do |i|
      run = parameter_set.runs.build
      run.submitted_to = @host
      run.save!
      created_runs << run
    end
    created_runs
  end

  def new_range_hashes(range_hash, relevant_factors)
    new_ranges = []

    ranges_array = managed_parameters_table.map {|mpt| mpt["key"]}.map.with_index do |key, index|
      ranges = [ range_hash[key] ]
      if relevant_factors.include?(index)
        range = range_hash[key]
        one_third = range[0]*2 / 3 + range[1]   /3
        two_third = range[0]   / 3 + range[1]*2 /3
        one_third = one_third.round(6) if one_third.is_a?(Float)
        two_third = two_third.round(6) if two_third.is_a?(Float)
        ranges = [
          [range.first, one_third], [one_third, two_third], [two_third, range.last]
        ]
      end
      ranges
    end

    #ranges_array = [@param_names[0], @param_names[1]].map do |key|
    #  ranges = [ range_hash[key] ]
    #  if relevant_factors.include?(key)
    #    range = range_hash[key]
    #    one_third = range.inject(:+) / 3
    #    two_third = range.inject(:+) * 2 / 3
    #    one_third = one_third.round(6) if one_third.is_a?(Float)
    #    two_third = two_third.round(6) if two_third.is_a?(Float)
    #    ranges = [
    #      [range.first, one_third], [one_third, two_third], [two_third, range.last]
    #    ]
    #  end
    #  ranges
    #end

    ranges_array.first.product( *(ranges_array[1..-1]) ).each do |a|
      h = { @param_names[0] => a[0], @param_names[1] => a[1]}
      new_ranges << h
    end
    new_ranges
  end


  def evaluate_runs

    super

    new_gen_range_hashes = []
    @range_hashes.each do |range_hash|
      #ps_array = get_parameter_sets_from_range_hash(range_hash)

      results = module_data.data["data_sets"][@num_iterations].map {|d| d["output"] }
      ef = FTest.eff_facts(@parameter_sets, results)

      relevant_factors = []
      managed_parameters_table.each_with_index do |mpt, index|
        relevant_factors << index if ef[index][:f_value] > module_data.data["_input_data"]["f_value_threshold"]
      end
      new_gen_range_hashes += new_range_hashes(range_hash, relevant_factors)
    end

    @range_hashes = new_gen_range_hashes
    @ranges_count += @range_hashes.count
  end

  def finished?
    puts "range_hashes is empty? #{@range_hashes.empty?}"
    puts "ranges_count = #{@ranges_count}"
    @range_hashes.empty? or @ranges_count > module_data.data["_input_data"]["range_count_max"]
     # @sim.parameter_sets.count > PS_COUNT_MAX
  end

  #override
  def get_target_fields(result)
    result.try(:fetch, module_data.data["_input_data"]["target_field"])
  end
end
