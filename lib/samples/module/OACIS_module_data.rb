class OacisModuleData

  private
  def data_struct
    {
     "data_sets"=>[] #[[{"input"=>[5,0],"output"=>[25]}, ..., {"input"=>[0,0],"output"=>[0]}]]
    }
  end

  public
  def set_data(h)
    @data = h
  end

  def data
    @data ||= data_struct
  end

  def get_datasets(iteration, index)
    data["data_sets"][iteration] = [] if data["data_sets"][iteration].nil?
    data["data_sets"][iteration][index] ||= {"input"=>[],"output"=>[]}
  end

  def set_datasets(iteration, index, val)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    val.each do |key,val|
      get_datasets(iteration, index)[key]=val
    end
  end

  def get_input(iteration, index)
    get_datasets(iteration, index)["input"]
  end

  def set_input(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_input(iteration, index)
    h = get_datasets(iteration, index)
    val.each_with_index do |v, d|
      a[d] = v
      h["input"][d] = v
    end
  end

  def get_output(iteration, index)
    get_datasets(iteration, index)["output"]
  end

  def set_output(iteration, index, val)
    raise "val must be a Array" unless val.is_a?(Array)
    a = get_output(iteration, index)
    val.each_with_index do |v, i|
      a[i] = v
    end
  end
end
