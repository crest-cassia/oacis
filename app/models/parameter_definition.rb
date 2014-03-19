class ParameterDefinition
  include Mongoid::Document

  field :key, type: String
  field :type, type: String
  field :default  # type is dynamically determined
  field :description, type: String

  embedded_in :simulator

  validates :key, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :type, presence: true, inclusion: { in: ParametersUtil::TYPES }
  validate :cast_default_value

  def cast_default_value
    return unless errors.empty?
    casted = ParametersUtil.cast_value(self.default, self.type)
    errors.add(:default, "can not be casted to #{self.type}") if casted.nil?
    self.default = casted
  end
end
