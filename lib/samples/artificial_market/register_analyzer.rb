require 'pp'

sim = Simulator.where(name: "ArtificialMarket_TickSizeDependency").first
raise "simulator is not found" unless sim

script = File.join(File.dirname(File.expand_path(__FILE__)), 'analyze_execution_rate.rb')
azr = sim.analyzers.find_or_create_by(name: "ExecutionRateAnalysis",
                                      type: :on_parameter_set_group,
                                      parameter_definitions: {},
                                      command: "ruby #{script}"
                                      )

ps_ary = sim.parameter_sets.where("v.InitialMarketWeightA" => 0.8)
psg = sim.parameter_set_groups.create!(parameter_sets: ps_ary)
arn = psg.analysis_runs.build(analyzer: azr)
arn.save and arn.submit
