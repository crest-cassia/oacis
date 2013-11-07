require 'json'
require_relative '../OACIS_module.rb'

class ExhaustiveRunner < OacisModule

  def initialize(input_data)
    @sim = Simulator.find("527b26188d57221193000003")
    @host = Host.find("527b17848d5722765a000001")
  end

  def generate_runs
    noise_array = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5]
    num_games_array = [5,6,7,8,9,10,11]
    created_runs = []
    noise_array.each do |noise|
      num_games_array.each do |num_games|
        ps = @sim.parameter_sets.build({"v" => {"noise" => noise, "num_games" => num_games}})
        if ps.save
          run = ps.runs.build
          run.submitted_to = @host
          run.save!
          created_runs << run
        end
      end
    end
    created_runs
  end

  def evaluate_runs
    # do nothing
  end

  def finished?
    true
  end

  def dump_serialized_data
  end
end
