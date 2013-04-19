#!/usr/bin/env ruby
unless ARGV.size == 8
  raise "format of ARGV: lane_length, v_max, lambda, signal_int0, signal_int1, signal_phase_diff, t_movie, seed"
end
lane_length, v_max, l, signal_interval0, signal_interval1, signal_phase_diff, t_movie, seed = ARGV

Simulator = File.join( File.dirname(__FILE__), 'traffic_NSmodel.out')
SignalPosition = [30, 45] # fix the signal positions

cmd = "#{Simulator} #{seed} #{t_movie} #{lane_length} #{v_max} #{l}"
cmd += " -signal #{SignalPosition[0]} #{signal_interval0} 0"
cmd += " -signal #{SignalPosition[1]} #{signal_interval1} #{signal_phase_diff}"

$stdout.puts cmd
system(cmd)
