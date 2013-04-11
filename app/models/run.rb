class Run
  include Mongoid::Document
  include Mongoid::Timestamps
  field :status, type: Symbol  # created, failed, canceled, finished
  field :seed, type: Integer
  field :hostname, type: String
  field :cpu_time, type: Float
  field :real_time, type: Float
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :included_at, type: DateTime
  belongs_to :parameter
  # belongs_to :job

  # validations
  validates :status, :presence => true
  validates :seed, :presence => true
  # IMPLEMENT ME: other validations

  before_validation :set_status, :set_unique_seed

  private
  def set_status
    self.status ||= :created
  end

  SeedMax = 2 ** 31
  SeedIterationLimit = 1024
  def set_unique_seed
    unless self.seed
      SeedIterationLimit.times do |i|
        candidate = rand(SeedMax)
        if self.class.where(:parameter_id => parameter, :seed => candidate).exists? == false
          self.seed = candidate
          break
        end
      end
      errors.add(:seed, "Failed to set unique seed") unless seed
    end
  end

end
