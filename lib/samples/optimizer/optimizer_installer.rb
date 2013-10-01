require 'pp'

puts "This installer regits an optimizer to CM."
if Simulator.count == 0
  puts "There are no simulators in CM."
  exit(-1)
end
puts "commands: reset   (discard all settings and return to first stage.)"
puts "          exit    (discard settings and exit.)"
puts ""

$stages=["init","set_name","select_simulator","select_managed_parameters","set_managed_parameters","finish"]
$stage_counter=0
$sim_id=nil
$sim=nil
$managed_params=[]
$name=nil

def simulator_list
  puts "install stage: "+$stages[$stage_counter]
  pp Simulator.each_with_index.map{ |s,i| i.to_s+":"+s.name }.join(",")
  puts "select num:"
end

def parameter_list
  puts "install stage: "+$stages[$stage_counter]
  pp $sim.parameter_definitions.each_with_index.map{|p,i| i.to_s+":"+p["key"].to_s+","+p["type"].to_s+","+p["default"].to_s+","+p["description"].to_s}
  puts "select nums:"
end

def set_opt_parameter(index)
  puts "install stage: "+$stages[$stage_counter]
  para = $sim.parameter_definitions[index]
  pp para["key"]
  puts "set range:"
  str = STDIN.gets
  if ["reset","restart"].include?(str.chomp)
    $stage_counter -= 1
  end
  if $stages[$stage_counter] == "set_managed_parameters"
    case para["type"]
    when "Integer"
      range = str.chomp.split(",").map{|s| s.to_i}
    when "Float"
      range = str.chomp.split(",").map{|s| s.to_f}
    when "Boolean"
      range = str.chomp.split(",").map{|s| s.to_b}
    when "String"
      range = str.chomp.split(",")
    end
  end
  $managed_params[index]={"key" => para["key"], "type" => para["type"], "default" => para["default"], "descritption" => para["descritoteion"], "range" => range}
end

def input_name
  puts "Input optimizer name"
end

def message(stage)
  case stage
  when "init"
    $stage_counter += 1
    input_name
  when "set_name"
    $stage_counter += 1
    simulator_list
  when "select_simulator"
    $stage_counter += 1
    parameter_list
  end
end

message($stages[$stage_counter])

while str = STDIN.gets
  break if ["exit","quit","bye"].include?(str.chomp)
  if str.chomp == ""
    next
  end
  if ["reset","restart"].include?(str.chomp)
    $stage_counter = 0
    message($stage_counter)
    next
  end

  case $stages[$stage_counter]
    when "set_name"
      $name=str.chomp
      message($stages[$stage_counter])
    when "select_simulator"
      if str == "0" or str.to_i
        $sim_id=Simulator.all.to_a[str.to_i].id
        $sim=Simulator.find($sim_id)
        message($stages[$stage_counter])
      end
    when "select_managed_parameters"
      params = str.chomp.split(",").map{|s| s.to_i}
      pp params
      $stage_counter += 1
      params.each do |i|
        if $stages[$stage_counter] == "set_managed_parameters"
          set_opt_parameter(i)
        end
      end
      if $stages[$stage_counter] == "set_managed_parameters"
        $stage_counter += 1
      else
        $stage_counter = 0
      end
  end
  break if $stage_counter == ($stages.length - 1)
end

puts ""
puts "New optimizer is installed."
puts "Optimizer name is \""+$name+"\""
puts "Managed parameter(s) is(are)"
pp $managed_params
