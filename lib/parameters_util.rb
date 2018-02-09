module ParametersUtil

  TYPES = ["Integer","Float","String"]

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
    when "String"
      return val.to_s
    else
      raise "Unknown type : #{type}"
    end
  end
end
