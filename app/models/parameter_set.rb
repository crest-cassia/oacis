class ParameterSet
  include Mongoid::Document
  include Mongoid::Timestamps
  field :v, type: Hash
  belongs_to :simulator
  has_many :runs
  has_many :analyses, as: :analyzable

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

  def runs_status_count
    counts = {}
    counts[:total] = runs.count
    counts[:finished] = runs.where(status: :finished).count
    counts[:running] = runs.where(status: :running).count
    counts[:failed] = runs.where(status: :failed).count
    counts
  end

  private
  def cast_and_validate_parameter_values
    unless v.is_a?(Hash)
      errors.add(:v, "v is not a Hash")
      return
    end

    return unless self.simulator # presence of simulator is checked by another validator

    # cast parameter values
    defn = self.simulator.parameter_definitions
    casted = ParametersUtil.cast_parameter_values(v, defn, errors)
    if errors.any?
      return
    end
    self.v = casted

    found = self.class.find_identical_parameter_set(simulator, v)
    if found and found.id != self.id
      errors.add(:parameters, "An identical parameters already exists : #{found.to_param}")
      return
    end
  end

  def self.find_identical_parameter_set(simulator, sim_param_hash)
    self.where(:simulator => simulator, :v => sim_param_hash).first
  end

  def create_parameter_set_dir
    FileUtils.mkdir_p(ResultDirectory.parameter_set_path(self))
  end
end
