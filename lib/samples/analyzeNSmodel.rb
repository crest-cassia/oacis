require 'environment'
require 'pp'

# returns average number of cars
def average_num_cars(runs)
  sum = 0.0
  n = runs.count
  runs.each do |run|
    sum += File.open( run.dir.join('result.txt'), 'r').readlines[0].to_f
  end
  average = sum / n

  sum = 0.0  
  runs.each do |run|
    val = File.open( run.dir.join('result.txt'), 'r').readlines[0].to_f
    sum += (val - average) * (val - average)
  end
  error = Math.sqrt(sum / n.to_f / (n-1).to_f)

  return average, error
end

def make_figure(run)
  vis_jar = Rails.root.join('vendor/sample_simulators/NS_model/Traffic_visualizer/Traffic_visualizer.jar')
  Dir.chdir(run.dir) {
    return if File.exist?("right.png")
    cmd = "java -jar #{vis_jar} map.txt"
    puts cmd
    system(cmd)
  }
end

# prm_id = ARGV[0]
sim = Simulator.where(name: "NSmodelWithTrafficSignals").first
key = "signal_phase_diff"
[10,12,14,16,18,20].each do |t2|
  base_prm = ParameterSet.where("v.T_signal2" => t2).first
  pp base_prm
  filename = "phase_diff_#{t2}.txt"
  io = File.open(filename, 'w')
  base_prm.parameter_sets_with_different(key).each do |prm|
    make_figure(prm.runs.first)
    io.puts "#{prm.v[key]} #{average_num_cars(prm.runs).join(' ')}"
  end
  io.close
end
