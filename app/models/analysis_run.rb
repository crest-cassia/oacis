class AnalysisRun
  include Mongoid::Document
  include Mongoid::Timestamps

  field :parameters, type: Hash
  field :result
  field :status, type: Symbol
  belongs_to :analyzer
  embedded_in :analyzable, polymorphic: true

  validates :parameters, presence: true
  validates :status, presence: true,
                     inclusion: {in: [:created,:running,:including,:failed,:canceled,:finished]}
  validates :analyzer, :presence => true
  before_validation :set_status

  attr_accessible :parameters, :analyzer

  private
  def set_status
    self.status ||= :created
  end
end
