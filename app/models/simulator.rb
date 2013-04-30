class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :parameter_definitions, type: Hash
  field :execution_command, type: String
  field :description, type: String
  has_many :parameter_sets
  embeds_many :analyzers

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :execution_command, presence: true
  validate :parameter_definitions_format

  after_save :create_simulator_dir

  public
  def dir
    ResultDirectory.simulator_path(self)
  end

  def analyzers_on_run
    self.analyzers.where(type: :on_run)
  end
  
  private
  def parameter_definitions_format
    unless parameter_definitions.size > 0
      errors.add(:parameter_definitions, "parameter definitions cannot be empty")
      return
    end
    parameter_definitions.each do |key, value|
      unless key =~ /\A\w+\z/
        errors.add(:parameter_definitions, "parameter name must match '/\A\w+\z/'")
        break
      end
      unless value.has_key?("type")
        errors.add(:parameter_definitions, "each parameter must has a type")
        break
      end
      unless ["Boolean","Integer","Float","String"].include?(value["type"])
        errors.add(:parameter_definitions, "type of each parameter must either 'Boolean', 'Integer', 'Float', or 'String'")
        break
      end
    end
  end

  def create_simulator_dir
    FileUtils.mkdir_p(ResultDirectory.simulator_path(self))
  end
end
