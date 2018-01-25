class HostParameterDefinition
  include Mongoid::Document
  field :key, type: String
  field :default, type: String
  field :format, type: String

  embedded_in :host

  validates :key, presence: true, uniqueness: true, format: {with: /\A\w+\z/}
  validate :default_value_conform_to_format
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
end
