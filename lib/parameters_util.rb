module ParametersUtil

  def self.cast_parameter_values(parameters, definitions, errors = nil)
    casted = {}
    parameters ||= {}
    definitions.each do |key,defn|

      type = defn["type"]
      val = parameters[key] || defn["default"]

      # neither parameter and defualt value is specified
      if val.nil?
        errors.add(:parameters, "can not determine value for #{key}") if errors
        return nil
      end

      val = cast_value(val, type)
      errors.add(:parameters, "can not cast #{key} to #{type}") if val.nil?

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

  private
  def self.boolean(val)
    compare_value = val.is_a?(String) ? val.downcase : val
    case compare_value
      when "yes", "true", "ok", true, "1", 1, :true, :ok, :yes
        return true
      else
        return false
    end
  end
end
