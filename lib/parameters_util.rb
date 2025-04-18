module ParametersUtil

  TYPES = ["Integer","Float","String","Object","Selection"]

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

      # neither parameter and default value is specified
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

      # check if val is included in options
      if pdef.type == "Selection"
        options = pdef.options_array
        unless options.include?(val)
          if errors
            errors.add(key.to_sym, "is not included in options: #{options.inspect}")
          else
            return nil
          end
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
        nil
      else
        val.to_i
      end
    when "Float"
      if val.is_a?(String) and val !~ /^[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?$/
        nil
      else
        val.to_f
      end
    when "String"
      if val == ''
        nil
      else
        val.to_s
      end
    when "Object"
      if val.is_a?(String)
        JSON.is_json?(val) ? JSON.parse(val) : nil
      else
        val
      end
    when "Selection"
      if val == ''
        nil
      else
        val.to_s
      end
    else
      raise "Unknown type : #{type}"
    end
  end
end
