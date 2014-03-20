class OrthogonalColumn
  include Math

  OUTSIDE_PLUSE = "outside(+)"
  OUTSIDE_MINUS = "outside(-)"
  INSIDE = "inside"
  BOTH_SIDE = "both side"

  attr_reader :id
  attr_reader :parameter_name
  attr_reader :parameters
  attr_reader :level
  attr_reader :digit_num
  attr_reader :corresponds


  # start 2 levels of parameter
  def initialize(id, parameter_name, initial_parameters)
    @id = id
    @parameter_name = parameter_name
    @parameters = initial_parameters
    @level = initial_parameters.size
    @parameters.sort!
    @corresponds = {}
    @digit_num = @level / 2
    for i in 0...@level do
      bit = ("%0" + @digit_num.to_s + "b") % i
      @corresponds[bit] = @parameters[i]
    end
  end

  # check digit number 
  def equal_digit_num(old_digit_num)
    @digit_num = sqrt(@level).ceil
    if old_digit_num < @digit_num
      return true
    else
      return false
    end
  end

  # update digit number
  def padding(old_digit_num, old_level)
    old_bit_str = "%0" + old_digit_num.to_s + "b"
    new_bit_str = "%0" + @digit_num.to_s + "b"
    for i in 0...old_level
      @corresponds[new_bit_str % i] = @corresponds[old_bit_str % i]
      @corresponds.delete(old_bit_str % i)
    end
  end

  def update_level(addtional_levels)
    @level += addtional_levels
  end

  # in case of new parameter points, check & alignment parameter in order
  def assign_parameter(old_level, add_point_case, add_parameters)

    case add_point_case
    when OUTSIDE_PLUSE
      right_digit_of_max = @corresponds.max_by(&:last)[0]
      if right_digit_of_max[right_digit_of_max.size - 1] == "1"
        add_parameters.sort!
      else
        add_parameters.reverse!
      end
    when OUTSIDE_MINUS
      right_digit_of_min = @corresponds.min_by(&:last)[0]
      if right_digit_of_min[right_digit_of_min.size - 1] == "0"
        add_parameters.sort!
      else
        add_parameters.reverse!
      end
    when INSIDE
      digit_num_of_left_point = @corresponds.max_by { |item| (item[1] < add_parameters[0]) ? item[1] : -1}[0]
      if digit_num_of_left_point[digit_num_of_left_point.size - 1] == "0"
        add_parameters.reverse!
      else
        add_parameters.sort!
      end
    when BOTH_SIDE
      right_digit_of_max = @corresponds.max_by(&:last)[0]
      if right_digit_of_max[right_digit_of_max.size - 1] == "1"
        add_parameters.reverse!
      else
        add_parameters.sort!
      end
    else
      p "error"
    end
    @parameters += add_parameters
    link_parameter(old_level)
  end

  # bit string link to parameters
  def link_parameter(old_level)
    for i in old_level...@level do
      bit = ("%0" + @digit_num.to_s + "b") % i
      if !@corresponds.key?(bit)
        @corresponds[bit] = @parameters[i]
      end
    end
  end

  # 
  def get_parameter(bit_string)
    return @corresponds[bit_string]
  end
  # 
  def get_bit_string(valiable)
    return @corresponds.key(valiable)
  end
  # 
  def get_bit_string_set(parameter)
    if parameter[:name] != @parameter_name
      return nil
    end
    bit_string = []
    parameter[:paramDefs].each{ |v| bit_string.push(@corresponds.key(v)) }
    return bit_string
  end
end