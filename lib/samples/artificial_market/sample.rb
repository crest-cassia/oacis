require 'pp'

sim = Simulator.where(name: "ArtificialMarket_TickSizeDependency").first
raise "simulator not found" unless sim

tb_ary = [1, 10, 100]
tau_ary = [1, 10, 100, 1000, 10000]
init_weight_ary = [0.2, 0.4, 0.6, 0.8]
weight2_ary = [1.0, 5.0, 10.0, 100.0]
weight3_ary = [1.0, 5.0, 100.0]
base = ParameterSet.where(simulator_id: sim).first.v.dup

NUM_RUNS = 4

tb_ary.product(tau_ary, init_weight_ary, weight2_ary, weight3_ary).product do |ary|
  ticksize_B, taumax, init_weight, weight2, weight3 = *(ary[0]) #, ary[1], ary[2], ary[3], ary[4], ary[5]
  puts "weight2: #{weight2}"
  puts "weight3: #{weight3}"
  puts "init_weight: #{init_weight}"
  puts "ticksize_B: #{ticksize_B}"
  puts "taumax: #{taumax}"

  new_param = base.merge({"TickSizeB" => ticksize_B, "TauMax" => taumax, "InitialMarketWeightA" => init_weight, "Weight2Max" => weight2, "Weight3Max" => weight3})
  prm = sim.parameter_sets.where(:v => new_param).first
  prm = sim.parameter_sets.create!(:v => new_param) unless prm
  (NUM_RUNS - prm.runs.count).times do |i|
    run = prm.runs.create!
    run.submit
  end
end
