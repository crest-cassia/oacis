class AnalysisRun
  include Mongoid::Document
  include Mongoid::Timestamps

  field :parameters, type: Hash
  field :result
  field :status, type: Symbol

  belongs_to :analyzer
  def analyzer  # find embedded document
    analyzer = nil
    if analyzer_id and analyzable
      analyzable.simulator.analyzers.find(analyzer_id)
    end
  end
  embedded_in :analyzable, polymorphic: true

  before_validation :set_status
  validates :parameters, presence: true
  validates :status, presence: true,
                     inclusion: {in: [:created,:running,:including,:failed,:canceled,:finished]}
  validates :analyzable, :presence => true
  validates :analyzer, :presence => true
  validate :cast_and_validate_parameter_values

  attr_accessible :parameters, :analyzer

  # TODO: cast parameters

  private
  def set_status
    self.status ||= :created
  end

  def cast_and_validate_parameter_values
    unless parameters.is_a?(Hash)
      errors.add(:parameters, "parameters is not a Hash")
      return
    end

    return unless analyzer
    defn = analyzer.parameter_definitions
    casted = ParametersUtil.cast_parameter_values(parameters, defn)
    if casted.nil?
      errors.add(:parameters, "parameters are invalid. See the definition.")
      return
    end
    self.parameters = casted
  end
end
