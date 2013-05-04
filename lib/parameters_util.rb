module ParametersUtil

  def self.cast_parameter_values(parameters, definitions, errors = nil)
    casted = {}
    definitions.each do |key,defn|

      type = defn["type"]
      val = parameters[key] || defn["default"]

      # neither parameter and defualt value is specified
      if val.nil?
        errors.add(:parameters, "can not determine value for #{key}") if errors
        return nil
      end

      case type
      when "Integer"
        val = val.to_i
      when "Float"
        val = val.to_f
      when "Boolean"
        val = boolean(val)
      when "String"
        val = val.to_s
      else
        raise "Unknown type : #{type}"
      end
      casted[key] = val
    end
    return casted
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