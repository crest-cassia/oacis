require 'json'
require_relative '../OACIS_module.rb'
require_relative 'f_test.rb'

class DOERunner < OacisModule

  NUM_RUNS = 5
  PS_COUNT_MAX = 80
  RANGE_COUNT_MAX = 30

  def initialize(input_data = nil)
    @sim = Simulator.where(name: "dilemma_game").first
    raise "Simulator 'dilemma_game' is not found" unless @sim
    @host = Host.where(name: "localhost").first
    raise "Host 'localhost' is not found" unless @host

    noise_array = [0, 0.05]
    num_games_array = [10, 100]

    if input_data
      noise_array = input_data[:noise_array]
      num_games_array = input_data[:num_games_array]
    end

    @ranges_count = 0

    @range_hashes = [ {noise_array: noise_array, num_games_array: num_games_array} ]
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
    noise_array = range_hash[:noise_array]
    num_games_array = range_hash[:num_games_array]

    noise_array.each do |noise|
      num_games_array.each do |num_games|
        parameter_sets << get_parameter_set(noise, num_games)
      end
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

  def evaluate_runs

    new_gen_range_hashes = []
    @range_hashes.each do |range_hash|
      noise_array = range_hash[:noise_array]
      num_games_array = range_hash[:num_games_array]

      ps_array = []
      noise_array.each do |noise|
        num_games_array.each do |num_games|
          ps = ParameterSet.where("v.noise" => noise, "v.num_games" => num_games).first
          raise "ps not found" unless ps
          ps_array << ps
        end
      end
    
      ef = FTest.eff_facts(ps_array)

      if ef["noise"][:f_value] > 10.0 && ef["num_games"][:f_value] > 10.0
        noise_half = noise_array.inject(:+) / 2.0
        num_games_half = num_games_array.inject(:+) / 2
        
        range_hash = {
          noise_array: [noise_half, noise_array.last],
          num_games_array: [num_games_half, num_games_array.last]
        }
        new_gen_range_hashes << range_hash

        range_hash = {
          noise_array: [noise_array.first, noise_half],
          num_games_array: [num_games_array.first, num_games_half]
        }
        new_gen_range_hashes << range_hash

        range_hash = {
          noise_array: [noise_array.first, noise_half],
          num_games_array: [num_games_half, num_games_array.last]
        }
        new_gen_range_hashes << range_hash

        range_hash = {
          noise_array: [noise_half, noise_array.last],
          num_games_array: [num_games_array.first, num_games_half]
        }
        new_gen_range_hashes << range_hash

      end
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
