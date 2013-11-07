require 'pp'

def get_ps_array
  [
    ParameterSet.where("v.noise" => 0.5, "v.num_games" => 10).first,
    ParameterSet.where("v.noise" => 0.5, "v.num_games" => 9).first,
    ParameterSet.where("v.noise" => 0.0, "v.num_games" => 10).first,
    ParameterSet.where("v.noise" => 0.0, "v.num_games" => 9).first
  ]
end

$mean = 0
$ss = 0
$count = 0

ps_array = get_ps_array
ps_array.each do |ps|
  ps.runs.each do |run|
    cycles = run.analyses.first.result["Cycles"]
    $mean += cycles
    $ss += cycles * cycles
    $count += 1
  end
end

pp $mean, $ss, $count
$ct = $mean * $mean / $count.to_f
$mean /= $count.to_f

pp $ct, $mean

effFacts = ["noise", "num_games"].map do |parameter_key|
  effFact ={}
  effFact[:name] = parameter_key
  effFact[:results] = {}
  ps_array.each do |ps|
    effFact[:results][ps.v[parameter_key]] ||= []
    effFact[:results][ps.v[parameter_key]] += ps.runs.map {|run| run.analyses.first.result["Cycles"]}
  end

  effFact[:effect] = 0.0
  effFact[:results].each_value do |v|
    effFact[:effect] += (v.inject(:+) ** 2).to_f / v.size
  end
  effFact[:effect] -= $ct
  effFact[:free] = 1
  effFact
end

# pp effFacts

$s_e = $ss - ($ct + effFacts.inject(0) {|sum,ef| sum + ef[:effect]})
$e_f = $count - 1
effFacts.each do |ef|
  $e_f -= ef[:free]
end

$e_v = $s_e / $e_f
effFacts.each do |fact|
  fact[:f_value] = fact[:effect] / $e_v
end

pp effFacts
