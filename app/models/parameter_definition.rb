class ParameterDefinition
  include Mongoid::Document

  field :key, type: String
  field :type, type: String
  field :default  # type is dynamically determined
  field :description, type: String
  field :options, type: String # for Selection type. Separated by newlines, e.g., "option1\noption2"

  embedded_in :simulator

  before_validation :set_default_option, if: ->{ self.type == "Selection" }
  before_validation :set_options_blank, if: ->{ self.type != "Selection" }

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

  def set_default_option
    self.default = options_array.first
  end

  def set_options_blank
    self.options = nil
  end

  def options_array
    return [] if self.options.blank?
    self.options.split("\n").map(&:strip).reject(&:empty?)
  end

  def validate_options_for_selection
    arr = options_array
    if arr.blank?
      errors.add(:options, "cannot be empty for Selection type")
    elsif arr.uniq.size != arr.size
      errors.add(:options, "must be unique values")
    end
  end
end
