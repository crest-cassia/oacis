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
  embeds_many :analyzers

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :command, presence: true
  validate :parameter_definitions_format

  attr_accessible :name, :command, :description, :parameter_definitions

  ParameterTypes = ["Integer","Float","String","Boolean"]

  after_save :create_simulator_dir

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
    counts["total"] = 0
    counts["finished"] = 0
    counts["running"] = 0
    counts["failed"] = 0
    parameter_sets.only("runs.status").each do |param|
      runs_count = param.runs_status_count
      counts["total"] = counts["total"] + runs_count["total"]
      counts["finished"] = counts["finished"] + runs_count["finished"]
      counts["running"] = counts["running"] + runs_count["running"]
      counts["failed"] = counts["failed"] + runs_count["failed"]
    end
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
