require 'pp'

sim = Simulator.where(name: "ArtificialMarket_TickSizeDependency").first
raise "simulator not found" unless sim

ta_ary = [1, 2, 5, 10, 20, 50, 100]
tb_ary = [1, 2, 5, 10, 20, 50, 100]
tau_ary = [1000] # [1, 10, 100, 1000, 10000]
init_weight_ary = [0.8] # [0.2, 0.4, 0.6, 0.8]
weight2_ary = [10.0] #, 100.0]
weight3_ary = [1.0] #, 5.0, 100.0]
base = ParameterSet.where(simulator_id: sim).first.v.dup

NUM_RUNS = 4

ta_ary.product(tb_ary, tau_ary, init_weight_ary, weight2_ary, weight3_ary).product do |ary|
  ticksize_A, ticksize_B, taumax, init_weight, weight2, weight3 = *(ary[0])
  puts "weight2: #{weight2}"
  puts "weight3: #{weight3}"
  puts "init_weight: #{init_weight}"
  puts "ticksize_A: #{ticksize_A}"
  puts "ticksize_B: #{ticksize_B}"
  puts "taumax: #{taumax}"

  new_param = base.merge({"TickSizeA" => ticksize_A, "TickSizeB" => ticksize_B, "TauMax" => taumax, "InitialMarketWeightA" => init_weight, "Weight2Max" => weight2, "Weight3Max" => weight3})
  prm = sim.parameter_sets.find_or_create_by(:v => new_param)
  (NUM_RUNS - prm.runs.count).times do |i|
    run = prm.runs.create!
    run.submit
  end
end
