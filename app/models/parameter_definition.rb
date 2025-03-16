class ParameterDefinition
  include Mongoid::Document

  field :key, type: String
  field :type, type: String
  field :default  # type is dynamically determined
  field :description, type: String
  field :options, type: Array, default: []  # for Selection type, e.g., ["option1", "option2"]

  embedded_in :simulator

  validates :key, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validates :type, presence: true, inclusion: { in: ParametersUtil::TYPES }
  validate :cast_default_value
  validates :options, presence: true, if: ->{ self.type == "Selection" }
  validate :validate_options_for_selection, if: ->{ self.type == "Selection" }

  def cast_default_value
    return unless errors.empty?
    casted = ParametersUtil.cast_value(self.default, self.type)
    errors.add(:default, "can not be casted to #{self.type}") if casted.nil?
    self.default = casted
  end

  def validate_options_for_selection
    if options.blank?
      errors.add(:options, "cannot be empty for Selection type")
    elsif options.uniq.size != options.size
      errors.add(:options, "must be unique values")
    end
  end
end
