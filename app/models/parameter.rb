class Parameter
  include Mongoid::Document
  include Mongoid::Timestamps
  field :sim_parameters, type: Hash # , :default .   ### IMPLEMENT ME
  belongs_to :simulator

  validates :sim_parameters, :presence => true
  validates :simulator, :presence => true
  validate :cast_and_validate_sim_parameters

  private
  def cast_and_validate_sim_parameters
    unless sim_parameters.is_a?(Hash)
      errors.add(:sim_parameters, "Sim_parameters is not a Hash")
      return
    end

    unless simulator
      errors.add(:simulator, "Simulator is not found")
      return
    end

    unless simulator.parameter_keys.keys.sort == sim_parameters.keys.sort
      errors.add(:sim_parameters, "Sim_parameters do not have keys consistent with its Simulator")
      return
    end

    # cast parameter values
    cast_sim_parameters

    found = self.class.find_identical_parameter(simulator, sim_parameters)
    if found
      errors.add(:sim_parameters, "An identical parameters already exists : #{found.to_param}")
      return
    end
  end

  def cast_sim_parameters
    sim_parameters.each do |key,val|
      type = simulator.parameter_keys[key]["type"]
      case type
      when "Integer"
        val = val.to_i
      when "Float"
        val = val.to_f
      when "Boolean"
        val = !!val
      when "String"
        val = val.to_s
      else
        raise "Unknown type : #{type}"
      end
      sim_parameters[key] = val
    end
  end

  def self.find_identical_parameter(simulator, sim_param_hash)
    self.where(:simulator => simulator, :sim_parameters => sim_param_hash).first
  end
end
