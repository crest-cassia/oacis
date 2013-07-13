class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :parameter_definitions, type: Hash
  field :command, type: String
  field :description, type: String
  field :support_input_json, type: Boolean, default: true
  has_many :parameter_sets
  has_many :parameter_set_queries
  has_many :parameter_set_groups
  embeds_many :analyzers
  has_and_belongs_to_many :executable_on, class_name: "Host", inverse_of: :executable_simulators

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :command, presence: true
  validate :parameter_definitions_format

  attr_accessible :name, :command, :description, :parameter_definitions, :executable_on_ids

  ParameterTypes = ["Integer","Float","String","Boolean"]

  after_create :create_simulator_dir

  public
  def dir
    ResultDirectory.simulator_path(self)
  end

  def analyzers_on_run
    self.analyzers.where(type: :on_run)
  end

  def analyzers_on_parameter_set
    self.analyzers.where(type: :on_parameter_set)
  end

  def analyzers_on_parameter_set_group
    self.analyzers.where(type: :on_parameter_set_group)
  end

  def analyses(analyzer)
    raise "not supported type" unless analyzer.type == :on_parameter_set_group
    matched = []
    parameter_set_groups.each do |psg|
      matched += psg.analyses.where(analyzer: analyzer).all
    end
    matched
  end

  def params_key_count
    counts = {}
    parameter_definitions.keys.each do |key|
      kinds = parameter_sets.only("v").distinct("v."+key)
      counts[key] = []
      kinds.each do |k|
        counts[key] << {k.to_s => parameter_sets.only("v").where("v."+key => k).count}
      end
    end
    counts
  end

  def parameter_sets_status_count
    counts = {}
    counts[:total] = Run.where(simulator_id: self.id).count
    counts[:finished] = Run.where(simulator_id: self.id, status: :finished).count
    counts[:running] = Run.where(simulator_id: self.id, status: :running).count
    counts[:failed] = Run.where(simulator_id: self.id, status: :failed).count
    counts
  end

  private
  def parameter_definitions_format
    unless parameter_definitions.size > 0
      errors.add(:parameter_definitions, "cannot be empty")
      return
    end
    parameter_definitions.each do |key, value|
      unless key =~ /\A\w+\z/
        errors.add(:parameter_definitions, "name must match '/\A\w+\z/'")
        return
      end
      unless value.has_key?("type")
        errors.add(:parameter_definitions, "must have a type")
        return
      end
      unless ParameterTypes.include?(value["type"])
        errors.add(:parameter_definitions, "type must be either 'Boolean', 'Integer', 'Float', or 'String'")
        return
      end
      value["default"] = ParametersUtil.cast_value(value["default"], value["type"])
      if value["default"].nil?
        errors.add(:parameter_definitions, "default value of #{key} is not valid as #{value['type']}")
      end
    end
  end

  def create_simulator_dir
    FileUtils.mkdir_p(ResultDirectory.simulator_path(self))
  end
end
