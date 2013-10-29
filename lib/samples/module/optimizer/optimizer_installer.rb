require 'pp'
require 'json'
require Rails.root.to_s+'/lib/samples/module/optimizer/optimizer.rb'

class TermColor
  class << self
    # default color
    def reset     ; c  0 ; end
    def reset_i   ; ci 0 ; end

    # colors
    def red       ; c  31; end
    def green     ; c  32; end
    def blue      ; c  34; end
    def red_i     ; ci 31; end
    def green_i   ; ci 32; end
    def blue_i    ; ci 34; end

    # out put
    def c(num)
      print "\e[#{num.to_s}m"
    end

    def ci(num)
      "\e[#{num.to_s}m"
    end
  end
end

class Selector
  def initialize(stages, initial_data)
    @stages=stages
    @stage_counter = 0
    @initial_data=initial_data
    @data_cash=initial_data
  end

  def run
    while @stage_counter < @stages.length
      current_step = @stages[@stage_counter]
      current_step.init(@data_cash)
      while str = STDIN.gets
        exit(0) if ["exit","quit","bye"].include?(str.chomp)
        if str.chomp == "" or /^\s*#/ =~ str.chomp
          next
        end
        if ["reset","restart"].include?(str.chomp)
          @stage_counter = 0
          @data_cash = @initial_data
          current_step = @stages[@stage_counter]
          TermColor.red
          puts "restart from the first stage"
          TermColor.reset
          current_step.init(@data_cash)
          next
        end

        b = current_step.run(str.chomp)
        break if b == true
      end

      @data_cash=current_step.finalize
      @stage_counter+=1
    end
  end
end

class OptimizerSelect
  def init(target_sim)
    @steps=["init","set_name","set_type","select_analyzer","select_managed_parameters","set_managed_parameters","finish"]
    @sim=target_sim[0]
    @host=target_sim[1]
    @name=nil
    @anz=nil
    @managed_params=[]
    @step_counter=0
    message
    @step_counter += 1
    @opt_param_counter=0
    @optimizer_types=optimizer_types
    @optimizer_desctiptions={"GA"=>"default GA"}
  end

  def run(str)
    case @steps[@step_counter]
      when "set_name"
        set_name(str)
      when "set_type"
        set_type(str)
      when "select_analyzer"
        select_analyzer(str)
      when "select_managed_parameters"
        select_managed_parameters(str)
      when "set_managed_parameters"
        set_opt_parameter(str)
    end
    message
    @step_counter += 1
    return true if @step_counter == (@steps.length - 1)
  end

  def finalize
    b = []
    opt = Simulator.new
    opt.name = @name
    opt.parameter_definitions = opt_parameter_definitions
    opt.command = "ruby -r "+Rails.root.to_s+"/config/environment "+Rails.root.to_s+"/lib/samples/module/OACIS_module.rb"
    opt.support_input_json = true
    opt.support_mpi = false
    opt.support_omp = false
    opt.description = "A sample optimizer."
    b.push(opt.save)
    host = Host.where({name: "localhost"}).first
    if host.present?
      host.executable_simulator_ids.push(opt.to_param).uniq!
      b.push(host.save)
    end
    if b.all?
      TermColor.green
      puts "New optimizer is installed."
      TermColor.reset
    else
      TermColor.red
      puts "New optimizer is not installed."
      TermColor.reset
    end
    return @managed_params
  end

  private
  def set_name(str)
    @name=str
    puts "new optimizer name is "+TermColor.blue_i+"\""+@name+"\""+TermColor.reset_i
  end

  def set_type(str)
    if @optimizer_types.include?(str)
      @type=str
      puts "new optimizer type is "+TermColor.blue_i+"\""+@type+"\""+TermColor.reset_i
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a type of optimizer from "+@optimizer_types.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end
  
  def select_analyzer(str)
    if (str == "0" or str.to_i > 0) and (@sim.analyzers.count > str.to_i)
      @anz=@sim.analyzers.to_a[str.to_i]
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a number(Integer less than "+@sim.analyzers.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def select_managed_parameters(str)
    @params = str.split(",").map{|s| s.to_i if (s == "0" or s.to_i > 0) and (@sim.parameter_definitions.count > s.to_i)}.uniq.compact
    if @params.length > 0
      pp @params.map{|p| p.to_s+":"+@sim.parameter_definitions[p].key}
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter numbers(Integer less than "+@sim.parameter_definitions.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def set_opt_parameter(str)
    para=@sim.parameter_definitions[@params[@opt_param_counter]]
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
    @managed_params[@params[@opt_param_counter]]={"key" => para["key"], "type" => para["type"], "default" => para["default"], "descritption" => para["descritoteion"], "range" => range}
    @opt_param_counter+=1
    @step_counter -= 1 unless @opt_param_counter == @params.length
  end

  def input_name
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    puts "Input optimizer name:"
  end

  def type_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp @optimizer_types
    puts "Input optimizer type:"
  end

  def analyzer_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp @sim.analyzers.each_with_index.map{ |s,i| i.to_s+":"+s.name }.join(",")
    puts "select num:"
  end

  def parameter_list
    puts "selected analyzer is "+TermColor.blue_i+@anz.name+TermColor.reset_i
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp @sim.parameter_definitions.each_with_index.map{|p,i| i.to_s+":"+p["key"].to_s+","+p["type"].to_s+","+p["default"].to_s+","+p["description"].to_s}
    puts "select nums:"
  end

  def managed_parameter_message
    TermColor.green
    puts "install stage: "+@steps[@step_counter]
    TermColor.reset
    para = @sim.parameter_definitions[@params[@opt_param_counter]]
    pp para["key"]
    puts "set range:[min, max(, span)]"
  end

  def show_result
    puts ""
    puts "Optimizer name is "+TermColor.blue_i+"\""+@name+"\""+TermColor.reset_i
    puts "Target simulator is "+TermColor.blue_i+"\""+@sim.name+"\""+TermColor.reset_i
    puts "Target analyzer is "+TermColor.blue_i+"\""+@anz.name+"\""+TermColor.reset_i
    puts "Managed parameter(s) is(are)"
    TermColor.blue
    pp @managed_params.compact
    TermColor.reset
  end

  def message
    case @steps[@step_counter]
    when "init"
      input_name
    when "set_name"
      type_list
    when "set_type"
      analyzer_list
    when "select_analyzer"
      parameter_list
    when "select_managed_parameters"
      managed_parameter_message
    when "set_managed_parameters"
      show_result
    end
  end

  def opt_parameter_definitions
    a = []
    a.push(ParameterDefinition.new({"key"=>"target", "type"=>"String", "default" => {"Simulator"=>@sim.to_param,"Analyzer"=>@anz.to_param,"Host"=>@host.map{|h| h.to_param}}.to_json.to_s, "description" => "targets for operation"}))
    h = {"module"=>"optimization","type"=>@type,"settings"=>{"maximize"=>true}}
    h["settings"]["managed_parameters"]=[]
    @managed_params.each do |mpara|
      h["settings"]["managed_parameters"].push(mpara)
    end
    a.push(ParameterDefinition.new({"key"=>"operation", "type"=>"String", "default" => h.to_json.to_s, "description" => @optimizer_desctiptions[@type]}))
    a.push(ParameterDefinition.new({"key"=>"iteration", "type"=>"Integer", "default" => 2, "description" =>"max_iteration"}))
    a.push(ParameterDefinition.new({"key"=>"population", "type"=>"Integer", "default" => 32, "description" =>"max_iteration"}))
    a.push(ParameterDefinition.new({"key"=>"seed", "type"=>"Integer", "default" => 0, "description" =>"seed for an optimizer"}))
    return a
  end
end

class SimulatorSelect
  def init(target_sims)
    @steps=["init","select_simulator","select_host","finish"]
    @target_sims=target_sims
    @sim=nil
    @step_counter=0
    message
    @step_counter += 1
    @host=[]
  end

  def run(str)
    case @steps[@step_counter]
    when "select_simulator"
      select_simulator(str)
      message
    when "select_host"
      select_host(str)
      message
    end
    @step_counter += 1
    return true if @step_counter == @steps.length-1
  end

  def finalize
    return [@sim,@host]
  end

  private
  def select_simulator(str)
    if (str == "0" or str.to_i > 0) and (@target_sims.count > str.to_i)
      @sim=@target_sims.to_a[str.to_i]
    elsif @target_sims.map{|sim| sim.name}.include?(str)
      @sim=@target_sims.map{|sim| sim if sim.name == str}.compact.first
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a number(Integer less than "+@target_sims.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def select_host(str)
    hosts = Host.all.select{|h| h if h.executable_simulator_ids.map{|id| id.to_s}.include?(@sim.to_param)}.compact
    if (str == "0" or str.to_i > 0) and (@target_sims.count > str.to_i)
      @host.push(hosts[str.to_i])
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a number(Integer less than "+@target_sims.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def simulator_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp @target_sims.each_with_index.map{ |s,i| i.to_s+":"+s.name }.join(",")
    puts "select num:"
  end

  def host_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    hosts = Host.all.select{|h| h if h.executable_simulator_ids.map{|id| id.to_s}.include?(@sim.to_param)}.compact
    if hosts.length == 0
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:There is no host to execute the selected simulator.)***"
      puts "*****************************************"
      TermColor.reset
      exit(-1)
    end
    pp hosts.each_with_index.map{ |s,i| i.to_s+":"+s.name }.join(",")
    puts "select num:"
  end

  def show_result
    puts "selected simulator is "+TermColor.blue_i+"\""+@sim.name+"\""+TermColor.reset_i
  end

  def message
    case @steps[@step_counter]
    when "init"
      simulator_list
    when "select_simulator"
      host_list
    when "select_host"
      show_result
    end
  end
end

def target_simulators
  if $target_simulators==nil
    $target_simulators=Simulator.all.select {|sim| sim.analyzers.where(type: :on_run).count > 0}
  end
  $target_simulators
end

TermColor.green
puts "This installer regits an optimizer to OACIS."

if target_simulators.count == 0
  puts "There are no optimization target(simulator) in OACIS."
  exit(-1)
end

puts "commands: reset   (discard all settings and return to first stage.)"
puts "          exit    (discard settings and exit.)"
puts ""
TermColor.reset

selector = Selector.new([SimulatorSelect.new,OptimizerSelect.new],target_simulators)
selector.run