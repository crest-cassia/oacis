class HostParameterDefinition
  include Mongoid::Document
  field :key, type: String
  field :default, type: String
  field :format, type: String  # when options is not nil, format is ignored
  field :options, type: Array

  embedded_in :host

  before_validation do
    if self.options.present?
      self.format = nil
      self.default = self.options.first if self.default.blank?
    end
  end
  validates :key, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validate :default_value_conform_to_format, if: -> { format.present? }
  validate :options_must_be_string_array, if: -> { options.present? }
  validate :default_must_be_in_options, if: -> { options.present? }
  validate :reserved_words_are_not_used_in_key

  private
  def default_value_conform_to_format
    regexp = ::Regexp.new(self.format.to_s)
    unless regexp =~ self.default.to_s
      errors.add(:default, "does not match regexp #{self.format}")
    end
  end

  def reserved_words_are_not_used_in_key
    if JobScriptUtil::EXPANDED_VARIABLES.include?(key)
      errors[:base] << "#{key} is a reserved word. Cannot use it as a key."
    end
  end

  def options_must_be_string_array
    unless self.options.is_a?(Array) && self.options.all? {|opt| opt.is_a?(String)}
      errors.add(:options, "must be an array of strings")
    end
  end

  def default_must_be_in_options
    unless self.options.include?(self.default)
      errors.add(:default, "must be one of #{self.options}")
    end
  end
end
