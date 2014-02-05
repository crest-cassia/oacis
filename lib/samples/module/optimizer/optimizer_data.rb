class OptimizerData

  def data
    {"best"=>[], #[{"input"=>[5,0],"output"=>[25]}, ..., {"input"=>[0,0],"output"=>[0]}]
     "data_sets"=>[[]] #[[{"input"=>[5,0],"output"=>[25]}, ..., {"input"=>[0,0],"output"=>[0]}]]
    }
  end

  def result
    @result ||= data
  end

  def get_datasets(iteration, index)
    result["data_sets"][iteration][index] ||= {"input"=>[],"output"=>[]}
  end

  def set_datasets(iteration, index, val)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    val.each do |key,val|
      get_datasets(iteration, index)[key]=val
    end 
  end

  def get_best(iteration)
    result["best"][iteration] ||= {"input"=>[],"output"=>[]}
  end

  def set_best(iteration, val)
    raise "\"input\" key is necessary" unless val.keys.include?("input")
    raise "\"output\" key is necessary" unless val.keys.include?("output")
    val.each do |key,val|
      get_best(iteration)[key]=val
    end 
  end
end
