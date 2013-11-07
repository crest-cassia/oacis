require 'json'
require_relative '../OACIS_module.rb'
require_relative 'f_test.rb'

class DOERunner < OacisModule

  NUM_RUNS = 5
  PS_COUNT_MAX = 70

  def initialize(input_data = nil)
    @sim = Simulator.find("527b26188d57221193000003")
    @host = Host.find("527b17848d5722765a000001")

    @noise_array = [0, 0.05]
    @num_games_array = [10, 100]

    if input_data
      @noise_array = input_data[:noise_array]
      @num_games_array = input_data[:num_games_array]
    end
  end

  def generate_runs
    # noise_array = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
    # num_games_array = [5,6,7,8,9,10,11]
    created_runs = []
    @noise_array.each do |noise|
      @num_games_array.each do |num_games|
        ps = @sim.parameter_sets.build({"v" => {"noise" => noise, "num_games" => num_games}})
        if ps.save
          pp ps.v
          (NUM_RUNS - ps.runs.count).times do |i|
            run = ps.runs.build
            run.submitted_to = @host
            run.save!
            created_runs << run
          end
        else
          ps = @sim.parameter_sets.where( "v.noise" => noise, "v.num_games" => num_games).first
          pp ps.v
          (NUM_RUNS - ps.runs.count).times do |i|
            run = ps.runs.build
            run.submitted_to = @host
            run.save!
            created_runs << run
          end
        end
      end
    end
    created_runs
  end

  def evaluate_runs
    ps_array = []
    @noise_array.each do |noise|
      @num_games_array.each do |num_games|
        ps = ParameterSet.where("v.noise" => noise, "v.num_games" => num_games).first
        raise "ps not found" unless ps
        ps_array << ps
      end
    end
    
    ef = FTest.eff_facts(ps_array)
    return if @sim.parameter_sets.count > PS_COUNT_MAX

    range_hashes = []
    if ef["noise"][:f_value] > 10.0 && ef["num_games"][:f_value] > 10.0
      noise_half = @noise_array.inject(:+) / 2.0
      num_games_half = @num_games_array.inject(:+) / 2
      
      # DOERunner.new( {noise_array: [@noise_array[0], noise_half],
      #                 num_games_array: [@num_games_array[0], num_games_half]} ).run
      range_hash = {
        noise_array: [noise_half, @noise_array.last],
        num_games_array: [num_games_half, @num_games_array.last]
      }
      range_hashes << range_hash

      range_hash = {
        noise_array: [@noise_array.first, noise_half],
        num_games_array: [@num_games_array.first, num_games_half]
      }
      range_hashes << range_hash

      range_hash = {
        noise_array: [@noise_array.first, noise_half],
        num_games_array: [num_games_half, @num_games_array.last]
      }
      range_hashes << range_hash

      range_hash = {
        noise_array: [noise_half, @noise_array.last],
        num_games_array: [@num_games_array.first, num_games_half]
      }
      range_hashes << range_hash

    end

    range_hashes.each do |range_hash|
      DOERunner.new(range_hash).run
    end
  end

  def finished?
    true
  end

  def dump_serialized_data
  end
end
