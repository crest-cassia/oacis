require 'pp'
require 'json'
require 'readline'
require 'thor'

class TermColor
  class << self
    # default color
    def reset ; c 0 ; end
    def reset_i ; ci 0 ; end

    # colors
    def red ; c 31; end
    def green ; c 32; end
    def blue ; c 34; end
    def red_i ; ci 31; end
    def green_i ; ci 32; end
    def blue_i ; ci 34; end

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

 attr_reader :data_cash 

  def run
    while @stage_counter < @stages.length
      current_step = @stages[@stage_counter]
      current_step.init(@data_cash)
      while str = Readline.readline("> ", true)
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

class ModuleSetting

  def init(data)
    @data = data
    @steps=["init","set_name","select_managed_parameters","set_managed_parameters","finish"]
    @sim=@data["_target_simulator"]
    @name=nil
    @managed_params=[]
    @step_counter=0
    message
    @step_counter += 1
    @opt_param_counter=0
  end

  def run(str)
    case @steps[@step_counter]
      when "set_name"
        set_name(str)
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
    opt = Simulator.new
    opt.name = @name
    opt.parameter_definitions = opt_parameter_definitions
    opt.command = "ruby -r "+Rails.root.to_s+"/config/environment #{@data["_module_runner_path"]}"
    opt.support_input_json = true
    opt.support_mpi = false
    opt.support_omp = false
    opt.description = "### OacisModule\nThis module is installed by [OACIS\\_module\\_installer](/oacis_document/index.html)"
    opt.executable_on_ids << Host.where(name: "localhost").first.to_param if Host.where(name: "localhost").exists?
    return opt
  end

  private
  def set_name(str)
    @name=str
    puts "new module name is "+TermColor.blue_i+"\""+@name+"\""+TermColor.reset_i
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
    puts "Input module name:"
  end

  def parameter_list
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
    puts "Module name is "+TermColor.blue_i+"\""+@name+"\""+TermColor.reset_i
    puts "Target simulator is "+TermColor.blue_i+"\""+@sim.name+"\""+TermColor.reset_i
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
      parameter_list
    when "select_managed_parameters"
      managed_parameter_message
    when "set_managed_parameters"
      show_result
    end
  end

  def opt_parameter_definitions
    a = OacisModule.paramater_definitions(@sim, @data["_target_module"].definition)
    pd = @sim.parameter_definitions.build
    pd["key"] = "_managed_parameters"
    pd["type"] = "String"
    pd["default"] = @managed_params.compact.to_json
    a << pd
    pd = @sim.parameter_definitions.build
    pd["key"] = "_target"
    pd["type"] = "String"
    pd["default"] = {"Simulator"=>@sim.to_param, "Analyzer"=>@anz.try(:to_param), "RunsCount"=>@data["_target_runs_count"]}.to_json
    a << pd
    a
  end
end

class SimulatorSelect
  def init(data)
    @data = data
    @steps=["init","select_simulator","select_analyzer","set_num_runs","finish"]
    @target_sims=Simulator.all.select{|sim| sim.executable_on_ids.count > 0 }
    raise "There is no executable simulator in OACIS." if @target_sims.count == 0
    @sim=nil
    @anz=nil
    @num_runs=0
    @step_counter=0
    message
    @step_counter += 1
  end

  def run(str)
    case @steps[@step_counter]
    when "select_simulator"
      select_simulator(str)
      message
    when "select_analyzer"
      select_analyzer(str)
      message
    when "set_num_runs"
      set_num_runs(str)
      message
    end
    @step_counter += 1
    return true if @step_counter == @steps.length-1
  end

  def finalize
    return @data.merge!({"_target_simulator"=>@sim}).merge!({"_target_analyzer"=>@anz}).merge!({"_target_runs_count"=>@num_runs})
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
      puts "***ERROR:enter a name of simulators or a number(Integer less than "+@target_sims.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def simulator_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp @target_sims.each_with_index.map{ |s,i| {i.to_i => s.name} }
    puts "select num or name:"
  end

  def select_analyzer(str)
    if (str == "0" or str.to_i > 0) and (target_analyzers.count > str.to_i)
      @anz=target_analyzers.to_a[str.to_i]
    elsif target_analyzers.map{|anz| anz.name}.include?(str)
      @anz=target_analyzers.where(name: str).first
    elsif str == "nan" or str == "-1"
      @anz=nil
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a name of analyzers or a number(Integer less than "+@target_anzs.count.to_s+")***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def analyzer_list
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    pp target_analyzers.each_with_index.map{ |s,i| {i => s.name} }
    puts "select num or name:"
  end

  def set_num_runs(str)
    if str.to_i > 0
      @num_runs = str.to_i
    else
      TermColor.red
      puts "*****************************************"
      puts "***ERROR:enter a number(Integer more than zero)***"
      puts "*****************************************"
      TermColor.reset
      @step_counter -=1
    end
  end

  def message_for_set_num_runs
    TermColor.green
    puts "install stage: "+@steps[@step_counter+1]
    TermColor.reset
    puts "set num of runs in each parameter_sets:"
  end

  def show_result
    puts "selected simulator is "+TermColor.blue_i+"\"#{@sim.name}\""+TermColor.reset_i
    puts "selected analyzer is "+TermColor.blue_i+"\"#{@anz.name}\""+TermColor.reset_i if @anz
    puts "set num of runs is "+TermColor.blue_i+"\"#{@num_runs}\""+TermColor.reset_i
  end

  def message
    case @steps[@step_counter]
    when "init"
      simulator_list
    when "select_simulator"
      analyzer_list
    when "select_analyzer"
      message_for_set_num_runs
    when "set_num_runs"
      show_result
    end
  end

  def target_analyzers
    @target_analyzers ||= Analyzer.where(simulator_id: @sim.to_param)
  end
end

def set_target_module(module_path)
  puts "load #{module_path}"
  load "#{module_path}"
  puts "create #{get_class_name(module_path)} class"
  @target_module = Kernel.const_get(get_class_name(module_path))
end

def target_module
  @target_module
end

def create_runner(module_path, module_runner_path)
  io = File.open(module_runner_path, "w")
  str=<<EOS
require 'json'

require_relative '#{module_path.basename.expand_path(".")}'

def load_input_data
  if File.exist?("_input.json")
    io = File.open('_input.json', 'r')
    parsed = JSON.load(io)
    return parsed
  end
end

input_data = load_input_data

if input_data.blank?
  raise "_input.json is missing."
end

input_data["_target"]=JSON.parse(input_data["_target"])
input_data["_managed_parameters"]=JSON.parse(input_data["_managed_parameters"])

#{get_class_name(module_path)}.new(input_data).run
EOS
  io.puts str
  io.close
end

def get_class_name(module_path)
  module_path.basename.to_s.sub(/\.rb$/){""}.split('_').map {|s| s.capitalize }.inject(&:+)
end

TermColor.green
puts "This installer install a module to OACIS."
TermColor.reset
puts "commands: reset (discard all settings and return to first stage.)"
puts " exit (discard settings and exit.)"
puts ""

class OacisModuleInstaller < Thor

  desc 'make_install', "make a module and install it on OACIS"
  method_option :file,
    type:     :string,
    aliases:  '-f',
    desc:     'module file',
    required: true
  def make_install
    sim = build_module(options) 
    b = []
    b.push(sim.save)
    if b.all?
      TermColor.green
      puts "New module is installed."
      TermColor.reset
    else
      TermColor.red
      puts "New module is not installed."
      TermColor.reset
      exit -1
    end

    create_runner(@module_path, @module_runner_path)
  end

  desc 'make', "make a module"
  method_option :file,
    type:     :string,
    aliases:  '-f',
    desc:     'module file',
    required: true
  def make
    sim = build_module(options)
    b = []
    b.push(sim.valid?)
    if b.all?
      TermColor.green
      puts "New module is builded."
      TermColor.reset
      input = sim.parameter_definitions.inject({}) {|h, pd| h.merge!({pd["key"]=>pd["default"]})}
      input["_seed"]=123456789
      dirname = Pathname(@module_runner_path).expand_path(".").dirname
      io = File.open(dirname.join("_input.json"),"w")
      io.puts input.to_json
      io.close
    else
      TermColor.red
      puts "New module is not buidled."
      TermColor.reset
      sim.save!
      exit -1
    end

    create_runner(@module_path, @module_runner_path)
  end

  private
  def build_module(options)
    @module_path = Pathname(options[:file])
    raise "No such file #{@module_path}" unless File.exist?(@module_path)
    set_target_module(@module_path)
    @module_runner_path = @module_path.dirname.join(@module_path.basename.sub(/.rb/,"_runner.rb")).expand_path(".")
    selector = Selector.new([SimulatorSelect.new, ModuleSetting.new],{"_target_module"=>target_module, "_module_runner_path"=>@module_runner_path})
    selector.run
    return selector.data_cash
  end
end

OacisModuleInstaller.start(ARGV)

TermColor.reset

