module ParametersUtil

  TYPES = ["Integer","Float","String","Boolean"]

  def self.cast_parameter_values(parameters, definitions, errors = nil)
    casted = {}
    parameters = parameters.try(:with_indifferent_access) || {}

    # check if an unknown key exists or not
    residual_keys = parameters.keys.map(&:to_s) - definitions.map(&:key)
    if residual_keys.present?
      if errors
        errors.add(:v, "Unknown keys are given: #{residual_keys.inspect}")
      else
        return nil
      end
    end

    definitions.each do |pdef|
      key = pdef.key
      type = pdef.type
      val = parameters.has_key?(key) ? parameters[key] : pdef.default
      # parameters[key] can be false. Do not write 'val = parameters[key] || pdef.default'

      # neither parameter and defualt value is specified
      if val.nil?
        if errors
          errors.add(key.to_sym, "is not specified")
        else
          return nil
        end
      end

      val = cast_value(val, type)
      if val.nil?
        if errors
          errors.add(key.to_sym, "can not cast to #{type}")
        else
          return nil
        end
      end

      casted[key] = val
    end
    return casted
  end

  # returns nil if cast fails
  def self.cast_value(val, type)
    case type
    when "Integer"
      if val.is_a?(String) and val !~ /^[-+]?[0-9]+$/
        return nil
      end
      return val.to_i
    when "Float"
      if val.is_a?(String) and val !~ /^[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?$/
        return nil
      end
      return val.to_f
    when "Boolean"
      return boolean(val)
    when "String"
      return val.to_s
    else
      raise "Unknown type : #{type}"
    end
  end

  def self.boolean(val)
    compare_value = val.is_a?(String) ? val.downcase : val
    case compare_value
      when "yes", "true", "ok", true, "1", 1, :true, :ok, :yes
        return true
      else
        return false
    end
  end

  def self.get_operator_string(parameter, operator, definition)
    disp_operator = operator
    return operator unless definition

    if (["Integer", "Float"].include?(definition.type))
      idx = ParameterSetFilter.getNumTypeMatchers.index(operator)
      disp_operator = ParameterSetFilter.getNumTypeMatcherStrings[idx]  if idx >= 0 && idx < ParameterSetFilter::NumTypeMatcherStrings.length
    end
    disp_operator
  end

  def self.parse_query_str_to_hash(str)
    arr = str.split();
    h = {}
    return h if arr.length != 3
    ope = arr[1]
    if ParameterSetFilter.getNumTypeMatcherStrings.include?(arr[1])
      idx = ParameterSetFilter.getNumTypeMatcherStrings.index(ope)
      ope = ParameterSetFilter.getNumTypeMatchers[idx]
    end
    h["param"] = "#{arr[0]}"
    h["matcher"] = ope
    h["value"] = "#{arr[2]}"
    h
  end

  def self.parse_query_hash_to_str(hash, simulator)
    str = ""
    return str unless hash.present?

    hash.each do |key, criteria|
      pd = simulator.parameter_definition_for(key)
      criteria.each do |matcher, value|
        str = "#{key} " + self.get_operator_string(key, matcher, pd) + " #{value}"
      end
    end
    str
  end
end
