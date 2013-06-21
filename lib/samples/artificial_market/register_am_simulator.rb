require 'pp'

def create_simulator
  name = 'ArtificialMarket_TickSizeDependency'

  sim = Simulator.where(name: name).first
  return sim if sim

  command = '~/program/artifmarket_ticksizedep/am_tick_size.out _input.json'
  description = <<-EOS
    A simulator for Artificial Market.
    Code of the simulator is available at https://bitbucket.org/yohm/artifmarket_ticksizedep.
    There are two markets whose tick size are different.
    ....
  EOS

  h = { 
        "NumAgents" => {"type"=>"Integer", "description" => "number of agents", "default" => 1e3.to_i},
        "MaxOrders" => {"type"=>"Integer", "description" => "maximum number of orders for each agent", "default" => 10},
        "TMax" => {"type"=>"Integer", "description" => "simulation step", "default" => 1e7.to_i},
        "NumMarkets" => {"type"=>"Integer", "description" => "number of markets. must be 1 or 2", "default" => 2},
        "TickSizeA" => {"type"=>"Integer", "description" => "tick size of market A", "default" => 1e3.to_i},
        "TickSizeB" => {"type"=>"Integer", "description" => "tick size of market B", "default" => 1e2.to_i},
        "InitialMarketWeightA" => {"type"=>"Float", "description" => "initial weight of Market A. must be [0.0,1.0]", "default" => 0.9},
        "FundamentalPrice" => {"type"=>"Integer", "description" => "fundamental price", "default" => 1e6.to_i},
        "TauMax" => {"type"=>"Integer", "description" => "maximum value of tau", "default" => 1e4.to_i},
        "T_AB" => {"type"=>"Integer", "description" => "duration for which amount of market sales are calculated", "default" => 1e5.to_i},
        "TCancel" => {"type"=>"Integer", "description" => "cancel duration for orders", "default" => 2e4.to_i},
        "TCancel" => {"type"=>"Integer", "description" => "cancel duration for orders", "default" => 2e4.to_i},
        "Weight1Max" => {"type"=>"Float", "description" => "weight of fundamental term", "default" => 1.0},
        "Weight2Max" => {"type"=>"Float", "description" => "weight of technical term", "default" => 10.0},
        "Weight3Max" => {"type"=>"Float", "description" => "weight of noise term", "default" => 1.0},
        "Sigma_E" => {"type"=>"Float", "description" => "standard deviation of the noise term epsilon", "default" => 0.06},
        "P_sigma" => {"type"=>"Float", "description" => "standard deviation of fluctuation on target price", "default" => 3e4}
      }

  sim = Simulator.find_or_create_by(name: name,
                                    command: command,
                                    parameter_definitions: h,
                                    description: description)
  return sim
end

def create_on_run_analyzer(sim)
  name = "MakeTimePricePlot"

  found = sim.analyzers.where(name: name).first
  return found if found

  type = :on_run
  command = "~/program/artifmarket_ticksizedep/make_plot.sh"
  sim.analyzers.create!(name: name, type: type, command: command, parameter_definitions: {}, auto_run: :first_run_only)
end

def create_on_parameter_set_analyzer(sim)
  name = "ErrorAnalysis"

  found = sim.analyzers.where(name: name).first
  return found if found

  type = :on_parameter_set
  script = Rails.root.join('lib/samples/artificial_market/error_analysis.rb')
  command = "ruby #{script.expand_path.to_s}"
  sim.analyzers.create!(name: name, type: type, command: command, parameter_definitions: {}, auto_run: :yes)
end

sim = create_simulator
create_on_run_analyzer(sim)
create_on_parameter_set_analyzer(sim)
ps = sim.parameter_sets.create!(v: {})  # create a parameter set