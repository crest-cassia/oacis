class Simulator
  include Mongoid::Document
  include Mongoid::Timestamps
  field :name, type: String
  field :command, type: String
  field :description, type: String
  field :support_input_json, type: Boolean, default: false
  field :support_mpi, type: Boolean, default: false
  field :support_omp, type: Boolean, default: false
  field :pre_process_script, type: String

  embeds_many :parameter_definitions
  has_many :parameter_sets, dependent: :destroy
  has_many :parameter_set_queries, dependent: :destroy
  has_many :analyzers, dependent: :destroy
  has_and_belongs_to_many :executable_on, class_name: "Host", inverse_of: :executable_simulators

  validates :name, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validate :name_not_changed_after_ps_created
  validates :command, presence: true
  validates :parameter_definitions, presence: true

  accepts_nested_attributes_for :parameter_definitions, allow_destroy: true
  attr_accessible :name, :pre_process_script, :command, :description, :parameter_definitions_attributes, :executable_on_ids, :support_input_json, :support_omp, :support_mpi

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

  def params_key_count
    counts = {}
    parameter_definitions.each do |pd|
      key = pd.key
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

  def parameter_definition_for(key)
    found = self.parameter_definitions.detect do |pd|
      pd.key == key
    end
    found
  end

  private
  def create_simulator_dir
    FileUtils.mkdir_p(ResultDirectory.simulator_path(self))
  end

  def name_not_changed_after_ps_created
    if self.persisted? and self.parameter_sets.any? and self.name_changed?
      errors.add(:name, "is not editable when a parameter set exists")
    end
  end
end
