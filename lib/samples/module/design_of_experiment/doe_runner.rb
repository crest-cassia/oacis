require 'json'
require_relative '../OACIS_module.rb'
require_relative 'f_test.rb'
require_relative 'orthogonal_array'

class DOERunner < OacisModule

  NUM_RUNS = 5
  PS_COUNT_MAX = 80
  RANGE_COUNT_MAX = 30
  F_VALUE_THRESHOLD = 10.0

  def initialize(input_data = nil)
    @sim = Simulator.where(name: "dilemma_game").first
    raise "Simulator 'dilemma_game' is not found" unless @sim
    @host = Host.where(name: "localhost").first
    raise "Host 'localhost' is not found" unless @host

    noise_array = [0, 0.05]
    num_games_array = [10, 100]

    if input_data
      noise_array = input_data["noise"]
      num_games_array = input_data["num_games"]
    end

    @ranges_count = 0

    @range_hashes = [ {"noise" => noise_array, "num_games" => num_games_array} ]
  end

  def generate_runs
    created_runs = []
    pp @range_hashes
    @range_hashes.each do |range_hash|
      get_parameter_sets_from_range_hash(range_hash).each do |ps|
        created_runs += create_runs_for(ps)
      end
    end
    created_runs
  end

  private
  def get_parameter_sets_from_range_hash(range_hash)
    parameter_sets = []
    noise_array = range_hash["noise"]
    num_games_array = range_hash["num_games"]

    oa_param = []
    oa_param.push( {name: "noise", paramDefs: noise_array })
    oa_param.push( {name: "num_games", paramDefs: num_games_array })
    @orthogonal_array = OrthogonalArray.new(oa_param)

    @orthogonal_array.table.transpose.each do |row|
      noise_index = row.first.to_i
      num_games_index = row[1].to_i
      noise = noise_array[noise_index]
      num_games = num_games_array[num_games_index]
      parameter_sets << get_parameter_set(noise, num_games)
    end

    parameter_sets
  end

  def get_parameter_set(noise, num_games)
    ps = @sim.parameter_sets.where( "v.noise" => noise, "v.num_games" => num_games).first
    unless ps
      ps = @sim.parameter_sets.build({"v" => {"noise" => noise, "num_games" => num_games}})
      ps.save!
    end
    ps
  end

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

    ranges_array = ["noise", "num_games"].map do |key|
      ranges = [ range_hash[key] ]
      if relevant_factors.include?(key)
        range = range_hash[key]
        one_third = range.inject(:+) / 3
        two_third = range.inject(:+) * 2 / 3
        one_third = one_third.round(6) if one_third.is_a?(Float)
        two_third = two_third.round(6) if two_third.is_a?(Float)
        ranges = [
          [range.first, one_third], [one_third, two_third], [two_third, range.last]
        ]
      end
      ranges
    end

    ranges_array.first.product( *(ranges_array[1..-1]) ).each do |a|
      h = { "noise" => a[0], "num_games" => a[1]}
      new_ranges << h
    end

    new_ranges
  end


  def evaluate_runs

    new_gen_range_hashes = []
    @range_hashes.each do |range_hash|
      ps_array = get_parameter_sets_from_range_hash(range_hash)

      ef = FTest.eff_facts(ps_array)

      relevant_factors = ["noise", "num_games"].select do |key|
        ef[key][:f_value] > F_VALUE_THRESHOLD
      end

      new_gen_range_hashes += new_range_hashes(range_hash, relevant_factors)
    end

    @range_hashes = new_gen_range_hashes
    @ranges_count += @range_hashes.count
  end
  def finished?
    @range_hashes.empty? or @ranges_count > RANGE_COUNT_MAX
     # @sim.parameter_sets.count > PS_COUNT_MAX
  end

  def dump_serialized_data
  end
end
