require 'pp'

host = Host.where({name: "localhost"}).first
if host.blank?
  puts "This sample works on localhost. before installing this sample, you should regit localhost as Host on OACIS"
end

def parameter_definitions
  a = []
  a.push(ParameterDefinition.new({"key"=>"p1", "type"=>"Float", "default" => 0, "description" => "Parameter1"}))
  a.push(ParameterDefinition.new({"key"=>"p2", "type"=>"Float", "default" => 0, "description" => "Parameter2"}))
  return a
end

#create toy problem
if Simulator.where(:name => "ToyProblem01").present?
  Simulator.where(:name => "ToyProblem01").destroy
end
sim = Simulator.new
sim.name = "ToyProblem01"
sim.parameter_definitions = parameter_definitions
sim.command = Rails.root.to_s+"/lib/samples/optimizer/toy_problem01.sh"
sim.support_input_json = false
sim.support_mpi = false
sim.support_omp = false
sim.description = "A toy problem for the optimizer."
pp sim
sim.save!
anz = Analyzer.where(name: "Sample_Analyzer_for_optimizer").first
if anz.blank?
  anz = Analyzer.new
  anz.simulator_id=sim.to_param
  anz.auto_run = :yes
  anz.type = :on_run
  anz.name = "Sample_Analyzer_for_optimizer"
  anz.command = "ruby "+Rails.root.to_s+"/lib/samples/optimizer/sample_analyzer.rb"
  anz.description = "get Fitness from a result on run."
  anz.save!
else
  anz.simulator_id=sim.to_param
  anz.save
end
host = Host.where({name: "localhost"}).first
if host.present?
  host.executable_simulator_ids.push(sim.to_param).uniq!
  host.save
end
