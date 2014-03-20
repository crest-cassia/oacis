require_relative 'orthogonal_column'

# extend 2 levels orthogonal array
class OrthogonalArray

  attr_reader :table
  attr_reader :num_of_factor
  attr_reader :l_size #experiment size
  attr_reader :colums
  attr_reader :analysis_area

  # 
  def initialize(parameters)
    level = 2
    @table =[]
    @colums = []
    @analysis_area = []
    @num_of_factor = parameters.size

    l = 0
    l += 1 while level**l - 1 < @num_of_factor

    @l_size = level**l
    @max_assign_factor = level**l - 1
    vector = []
    (@l_size.to_s(2).size - 1).times{ vector.push([]) }

    for i in 0...@l_size
      j = 0
      sprintf("%0" + (@l_size.to_s(2).size - 1).to_s + "b", i).split('').each do |ch| 
        vector[j].push(ch)
        j += 1
      end
    end

    for i in 1..vector.size
      comb = vector.combination(i)
      col = 0
      comb.collect{|set|
        tmp = []
        for j in 0...set[0].size
          if 1 < set.size then
            sum = 0
            for k in 0...set.size
              sum += set[k][j].to_i(2)
            end
            tmp.push((sum % 2 == 0) ? "0" : "1" )# 0/1を入れていく
          else
            tmp.push(set[0][j])
          end
        end
        @table.push(tmp)
      }
    end

    id = 0
    parameters.each{|prm|
      oc = OrthogonalColumn.new(id , prm[:name], prm[:paramDefs])
      @colums.push(oc)
      id += 1
    }

    area = []
    @table[0].size.times{|i| area.push(i)}
    @analysis_area.push(area)
  end

  # 
  def extend_table(id_set, add_point_case, parameter)
    old_level = 0
    old_digit_num = 0
    twice = false
    ext_column = nil
    @colums.each{ |oc|
      if oc.parameter_name == parameter[:name]
        ext_column = oc
        old_level = oc.level        
        oc.update_level(parameter[:paramDefs].size)
        old_digit_num = oc.digit_num
        if oc.equal_digit_num(old_digit_num)
          oc.padding(old_digit_num, old_level)
          twice = true
          copy = []
          for i in 0...@table[oc.id].size
            copy.push("1" + @table[oc.id][i])
            @table[oc.id][i] = "0" + @table[oc.id][i]
          end
          @table[oc.id] += copy
          @l_size *= 2
        end
        oc.assign_parameter(old_level, add_point_case, parameter[:paramDefs])
        break
      end
    }
    if twice
      @table.each_with_index{|c, i|
        extend_flag = true
        @colums.each{|oc| 
          if oc.id == i && oc.parameter_name == parameter[:name]
            extend_flag = false
            break
          end 
        }
        if extend_flag
          copy = []
          @table[i].each{ |b| copy.push(b) }
          @table[i] += copy
        end
      }
    end
    return ext_column
  end

  # for a kind of parameter
  def generate_new_analysis_area(old_rows, new_param, exteded_column)
    new_rows = []
    # old_rows.each{|row| new_rows.push(row + (@table[exteded_column.id].size / 2))}
    add_point_case = new_param[:case]
    new_bit =[]
    id=nil
    @colums.each{|c|
      if c.parameter_name == new_param[:param][:name]
        id = c.id
        new_param[:param][:paramDefs].each{|v|
          new_bit.push(c.get_bit_string(v))
        }
        break
      end
    }
    # p "new bit: #{new_param[:param][:name]}"
    # pp new_bit

    @table[id].each_with_index{|v, i|
      new_bit.each{|b|
        if b == v
          # compare get_row(old_rows) with get_row(i)
          old_rows.each{|r|
            row_i = get_row(i)
            row_r = get_row(r)
            row_i.delete_at(id)
            row_r.delete_at(id)
            # if (row_i - row_r).size == 0
            #   new_rows.push(i)
            # end
            equal_flag = true
            row_i.size.times{|t|
              if row_i[t] != row_r[t]
                equal_flag = false
                break
              end
            }
            if equal_flag then new_rows.push(i) end
          }
        end
      }
    }
    new_rows.uniq!

    old_lower_value_rows = []
    old_upper_value_rows = []
    old_lower_value = nil
    old_upper_value = nil
    old_rows.each{ |row|
      if old_lower_value.nil? # old lower parameter
        old_lower_value_rows.push(row)
        old_lower_value = exteded_column.corresponds[@table[exteded_column.id][row]]
      else
        if exteded_column.corresponds[@table[exteded_column.id][row]] < old_lower_value
          old_lower_value_rows.clear
          old_lower_value_rows.push(row)
          old_lower_value = exteded_column.corresponds[@table[exteded_column.id][row]]
        elsif exteded_column.corresponds[@table[exteded_column.id][row]] == old_lower_value
          old_lower_value_rows.push(row)
        end
      end
      
      if old_upper_value.nil? # old upper parameter
        old_upper_value_rows.push(row)
        old_upper_value = exteded_column.corresponds[@table[exteded_column.id][row]]
      else
        if old_upper_value < exteded_column.corresponds[@table[exteded_column.id][row]]
          old_upper_value_rows.clear 
          old_upper_value_rows.push(row)
          old_upper_value = exteded_column.corresponds[@table[exteded_column.id][row]]
        elsif old_upper_value == exteded_column.corresponds[@table[exteded_column.id][row]]
          old_upper_value_rows.push(row)
        end
      end
    }

    new_lower_value_rows = []
    new_upper_value_rows = []
    new_lower_value = nil
    new_upper_value = nil
    new_rows.each{ |row|
      if new_lower_value.nil? # new lower parameter
        new_lower_value_rows.push(row)
        new_lower_value = exteded_column.corresponds[@table[exteded_column.id][row]]
      else
        if exteded_column.corresponds[@table[exteded_column.id][row]] < new_lower_value
          new_lower_value_rows.clear
          new_lower_value_rows.push(row)
          new_lower_value = exteded_column.corresponds[@table[exteded_column.id][row]]
        elsif exteded_column.corresponds[@table[exteded_column.id][row]] == new_lower_value
          new_lower_value_rows.push(row)
        end
      end
      
      if new_upper_value.nil? # new upper parameter
        new_upper_value_rows.push(row)
        new_upper_value = exteded_column.corresponds[@table[exteded_column.id][row]]
      else
        if new_upper_value < exteded_column.corresponds[@table[exteded_column.id][row]]
          new_upper_value_rows.clear
          new_upper_value_rows.push(row)
          new_upper_value = exteded_column.corresponds[@table[exteded_column.id][row]]
        elsif new_upper_value == exteded_column.corresponds[@table[exteded_column.id][row]]
          new_upper_value_rows.push(row)
        end
      end
    }

    generated_area = []
    case add_point_case
    when "outside(+)"
      # (new_lower, new_upper)
      generated_area.push(new_rows)
      # new area between (old_upper, new_lower)
      generated_area.push(old_upper_value_rows + new_lower_value_rows)
    when "outside(-)"
      # (new_lower, new_upper)
      generated_area.push(new_rows)
      # new area between (new_upper, old_lower)
      generated_area.push(new_upper_value_rows + old_lower_value_rows)
    when "inside"
      # (new_lower, new_upper)
      generated_area.push(new_rows)
      # between (old_lower, new_lower) in area
      generated_area.push(old_lower_value_rows + new_lower_value_rows)
      # between (old_upper, new_upper) in area
      generated_area.push(old_upper_value_rows + new_upper_value_rows)
    when "both side" # TODO
      
      # between (old_lower, new_lower) in area
      generated_area.push(old_lower_value_rows + new_lower_value_rows)
      # between (old_upper, new_upper) in area
      generated_area.push(old_upper_value_rows + new_upper_value_rows)
      # (new_lower, new_upper)
      generated_area.push(new_rows)
    else
      p "create NO area for analysis"
    end
    @analysis_area += generated_area
    return generated_area
  end

  # col番目のベクトルのrow番目に記述されたn水準のうちの1つを示す値を返す
  def get_index(col, row)
    return @table[col][row].to_i(2)
  end
  #
  def get_bit_string(col, row)
    return @table[col][row]
  end
  #
  def get_parameter(row, col)
    return @colums[col].get_parameter(@table[col][row])
  end
  # 
  def get_paramValues(row)
    p_set = []
    @colums.each{ |oc|
      p_set.push(get_parameter(row, oc.id))
    }
    return p_set
  end
  #
  def get_assigned_parameters
    show = []
    for i in 0...@table[0].size
      show.push(get_paramValues(i))
    end
    return show
  end
  # 直交表全体の確認
  def get_table
    table_info = []
    @table[0].size.times{ table_info.push([]) }
    for i in 0...@table.size
      for j in 0...@table[i].size
        table_info[j].push(table[i][j])
      end
    end
    return table_info
  end
  #ベクトルの取得
  def get_vector(col)
    return @table[col]
  end
  # return array of bit strings
  def get_row(row)
    bits = []
    @table.each{|col|
      bits.push(col[row])
    }
    return bits
  end
end