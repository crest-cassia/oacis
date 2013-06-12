require 'pp'

sim = Simulator.find('51b8210471410b2438000002')
tb_ary = [1, 2, 5, 10, 20, 50, 100, 200, 500]
tau_ary = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 10000]
init_weight_ary = [0.2, 0.4, 0.6, 0.8]
weight2_ary = [2.0, 4.0, 6.0, 8.0, 10.0]
base = ParameterSet.find('51b8218a71410b2438000004').v.dup

NUM_RUNS = 4

weight2_ary.each do |weight2|
init_weight_ary.each do |init_weight|
tb_ary.each do |ticksize_B|
  tau_ary.each do |taumax|
    puts "weight2: #{weight2}"
    puts "init_weight: #{init_weight}"
    puts "ticksize_B: #{ticksize_B}"
    puts "taumax: #{taumax}"
    new_param = base.dup.update({"TickSizeB" => ticksize_B, "TauMax" => taumax, "InitialMarketWeightA" => init_weight, "Weight2Max" => weight2})
    prm = sim.parameter_sets.where(:v => new_param).first
    prm = sim.parameter_sets.create!(:v => new_param) unless prm
    (NUM_RUNS - prm.runs.count).times do |i|
      run = prm.runs.create!
      run.submit
    end
  end
end
end
end
