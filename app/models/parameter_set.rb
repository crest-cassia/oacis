class ParameterSet
  include Mongoid::Document
  include Mongoid::Timestamps
  field :v, type: Hash # , :default .   ### IMPLEMENT ME
  belongs_to :simulator
  has_many :runs

  validates :v, :presence => true
  validates :simulator, :presence => true
  validate :cast_and_validate_parameter_values

  after_save :create_parameter_set_dir

  public
  def dir
    ResultDirectory.parameter_set_path(self)
  end

  def parameter_sets_with_different(key)
    query_param = { simulator: self.simulator }
    v.each_pair do |prm_key,prm_val|
      next if prm_key == key.to_s
      query_param["v.#{prm_key}"] = prm_val
    end
    self.class.where(query_param)
  end

  private
  def cast_and_validate_parameter_values
    unless v.is_a?(Hash)
      errors.add(:v, "v is not a Hash")
      return
    end

    unless simulator
      errors.add(:simulator, "Simulator is not found")
      return
    end

    unless simulator.parameter_definitions.keys.sort == v.keys.sort
      errors.add(:v, "v do not have keys consistent with its Simulator")
      return
    end

    # cast parameter values
    cast_parameter_values

    found = self.class.find_identical_parameter_set(simulator, v)
    if found and found.id != self.id
      errors.add(:v, "An identical parameters already exists : #{found.to_param}")
      return
    end
  end

  def cast_parameter_values
    v.each do |key,val|
      type = simulator.parameter_definitions[key]["type"]
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
      v[key] = val
    end
  end

  def self.find_identical_parameter_set(simulator, sim_param_hash)
    self.where(:simulator => simulator, :v => sim_param_hash).first
  end

  def create_parameter_set_dir
    FileUtils.mkdir_p(ResultDirectory.parameter_set_path(self))
  end
end
