require 'thor'
require 'pp'
require 'json'

class CliInstaller < Thor

  PS_TEMPLATE={"key"=>nil,"type"=>nil,"default"=>nil,"description"=>nil}

  DATA_TEMPLATE={
                  "simulator"=>{
                    "name"=>nil,
                    "parameter_definitions"=>[PS_TEMPLATE.dup],
                    "command"=>nil},
                }

  SIMULATOR_KEYS=["name","parameter_definitions"]

  desc 'new', "create new file(coution: overwritten)"
  def new
    save_data(DATA_TEMPLATE)
    save_temp_data(DATA_TEMPLATE)
    pp DATA_TEMPLATE
  end

  desc 'show [collection] [key]', "show data"
  method_option :key,
    :type     => :string,
    :aliases  => '-k',
    :desc     => 'collection[key]'
  def show
    data = load_temp_data
    data = "#{options[:key]}=#{get_value(data, options[:key])}" if options[:key]
    pp "data is not varid" unless valid?(data)
    pp data
  end

  desc 'valid', "create new file(coution: overwritten)"
  def valid
    data = load_temp_data
    if valid?(data)
      pp "data is valid"
    else
      pp "data is not valid"
    end
  end

  desc 'save', "save data to file"
  method_option :install,
    :type    => :boolean,
    :aliases => '-i',
    :desc    => 'with installing'
  def save
    data = load_temp_data
    save_data(data)
    install_data(data) if options[:install]
  end

  desc 'install', "save data to OACIS"
  def install
    data = load_data
    install_data(data)
  end

  desc 'set collection key val', "set a value to a field of collection"
  method_option :key,
    :type     => :string,
    :aliases  => '-k',
    :desc     => 'key',
    :required => true
  method_option :value,
    :type     => :string,
    :aliases  => '-v',
    :desc     => 'value',
    :required => true
  method_option :value_with_json,
    :type     => :boolean,
    :aliases  => '-js',
    :desc     => 'value_with_json'
  def set
    data = load_temp_data
    verify_json_value(options[:value]) if options[:value_with_json]
    set_value(data,options[:key], options[:value])
    save_temp_data(data)
    show_data = options[:key]
    show_data += "="+get_value(data, options[:key])
    pp show_data
  end

  desc 'reload', "reload data"
  method_option :collection,
    :type     => :string,
    :aliases  => '-c',
    :desc     => 'collection'
  def reload
    data = load_data
    if options[:collection]
      verify_collection(temp_data, options[:collection])
      temp_data = load_temp_data
      temp_data[options[:collection]]=data[options[:collection]]
    else
      temp_data=data
    end
    save_temp_data(temp_data)
    pp temp_data
  end

  desc 'push', 'push a new field'
  method_option :key,
    :type     => :string,
    :aliases  => '-k',
    :desc     => 'key',
    :required => true
  def push
    data = load_temp_data
    push_field(data, options[:key])
    save_temp_data(data)
    show_data = options[:key]
    show_data += "="+get_value(data, options[:key]).to_s
    pp show_data
  end

  desc 'delete', 'delete a field'
  method_option :key,
    :type     => :string,
    :aliases  => '-k',
    :desc     => 'key',
    :required => true
  def delete
    data = load_temp_data
    pp "#{delete_field(data, options[:key])} is deleted form #{options[:key]}"
    save_temp_data(data)
  end

  private
  def load_data
    if File.exist?("_install.js")
      io = File.open('_install.js', 'r')
      data = JSON.load(io)
    else
      data = DATA_TEMPLATE
      save_data(data)
    end
    data
  end

  def save_data(data)
    io = File.open("_install.js","w")
    io.puts JSON.pretty_generate(data)
  end

  def install_data(data)
    data.each do |key, val|
      case key
      when "simulator"
        sim = Simulator.new
        sim.name = val["name"]
        sim.command = val["command"]
        val["parameter_definitions"].each do |pd|
          ps = sim.parameter_definitions.build
          ps.key = pd["key"]
          ps.type = pd["type"]
          val = pd["derault"]
          val = val.to_i if pd["type"] == "Integer"
          val = val.to_f if pd["type"] == "Float"
          val = val.to_b if pd["type"] == "Boolean"
          ps.default = val
          ps.description = pd["descriotion"]
        end
        sim.save!
        pp sim
      else
        raise "No such key(#{key})"
      end
    end
  end

  def load_temp_data
    if File.exist?("._install.js")
      io = File.open('._install.js', 'r')
      data = JSON.load(io)
    else
      data = load_data
      save_temp_data(data)
    end
    data
  end

  def reload_data
    data = load_data
    data
  end


  def save_temp_data(data)
    io = File.open("._install.js","w")
    io.puts JSON.pretty_generate(data)
  end

  def verify_collection(h, key)
    raise "No such collection" unless h.keys.include?(key)
  end

  def set_value(data, key_set, val)
    keys = key_set.split(".")
    temp_data = data
    while keys
      key = keys.shift
      key = key.to_i if temp_data.is_a? Array
      if keys.length == 0
        temp_data[key]=val
        break
      end
      raise "No such key(#{key})" unless temp_data[key]
      temp_data = temp_data[key]
    end
  end

  def get_value(data, key_set)
    keys = key_set.split(".")
    temp_data = data
    while keys
      key = keys.shift
      key = key.to_i if temp_data.is_a? Array
      return temp_data[key] if keys.length == 0
      raise "No such key(#{key})" unless temp_data[key]
      temp_data = temp_data[key]
    end
  end

  def push_field(data, key_set)
    keys = key_set.split(".")
    collection = keys.first
    temp_data = data
    while keys
      key = keys.shift
      key = key.to_i if temp_data.is_a? Array
      if keys.length == 0
        pp temp_data
        temp_data[key].push(PS_TEMPLATE.dup) if collection == "simulator"
        break
      end
      raise "No such key(#{key})" unless temp_data[key]
      temp_data = temp_data[key]
    end
  end

  def delete_field(data, key_set)
    keys = key_set.split(".")
    temp_data = data
    while keys
      key = keys.shift
      key = key.to_i if temp_data.is_a? Array
      if keys.length == 0
        if temp_data.is_a? Array
          return temp_data.delete_at(key)
        end
      end
      raise "No such key(#{key})" unless temp_data[key]
      temp_data = temp_data[key]
    end
  end

  def valid?(data)
    data.each do |key, val|
      case key
      when "simulator"
        sim = Simulator.new
        sim.name = val["name"]
        sim.command = val["command"]
        val["parameter_definitions"].each do |pd|
          ps = sim.parameter_definitions.build
          ps.key = pd["key"]
          ps.type = pd["type"]
          val = pd["derault"]
          val = val.to_i if pd["type"] == "Integer"
          val = val.to_f if pd["type"] == "Float"
          val = val.to_b if pd["type"] == "Boolean"
          ps.default = val
          ps.description = pd["descriotion"]
        end
        return sim.valid?
      else
        raise "No such key(#{key})"
      end
    end
  end
end

CliInstaller.start
