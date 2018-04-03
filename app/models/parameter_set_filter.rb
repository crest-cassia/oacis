class ParameterSetFilter
  include Mongoid::Document
  field :enable, type: Boolean, default: true
  field :query, type: Hash
  belongs_to :filter_set
  belongs_to :simulator
  validates :simulator, presence: true
  validates :query, presence: true
  validate :validate_format_of_query

  NumTypeMatchers = ["eq", "ne", "gt", "gte", "lt", "lte"]
  NumTypeMatcherStrings = ["==", "!=", ">", ">=", "<", "<="]
  BooleanTypeMatchers = ["eq", "ne"]
  StringTypeMatchers = ["start_with", "end_with", "include", "match"]

  def validate_format_of_query
    unless !self.query.blank? && self.query.is_a?(Hash)
      self.errors.add(:query, "must be a Hash")
      return
    end

    self.query.each do |key,criteria|
      pd = simulator.parameter_definition_for(key)
      unless pd
        self.errors.add(:query, "does not have keys defined in parametr_set_definitions")
        return
      end

      unless criteria.is_a?(Hash)
        self.errors.add(:query, "criteria must be a Hash")
        return
      end

      # validate format of a matcher
      criteria.each do |matcher, value|
        type = pd.type
        unless supported_matchers(type).include?(matcher)
          self.errors.add(:query, "has unknown matcher : #{matcher}")
          return false
        end

        # validate type of a value
        klass = Kernel.const_get(type)
        unless value.is_a?(klass)
          self.errors.add(:query, "#{value.inspect} must be a #{type}")
          return false
        end
      end
    end
  end

  private
  def supported_matchers(type)
    supported_matchers = []
    case type
    when "Integer", "Float"
      supported_matchers = NumTypeMatchers
    when "Boolean"
      supported_matchers = BooleanTypeMatchers
    when "String"
      supported_matchers = StringTypeMatchers
    else
      raise "not supported type"
    end
    return supported_matchers
  end

  def string_matcher_to_regexp(matcher, value)
    case matcher
    when "start_with"
      /\A#{value}/
    when "end_with"
      /#{value}\z/
    when "include"
      /#{value}/
    when "match"
      /\A#{value}\z/
    else
      raise "not supported matcher : #{matcher}"
    end
  end

  public
  #ser a query which is a hash expressed with string in key and val
  def set_query(settings)
    return false if settings.blank?

    h = {}
    settings.each do |para|
      parameter = para['param']
      defn = simulator.parameter_definition_for(parameter)
      type = defn.type
      value = para['value']
      matcher = para['matcher']

      # cast value to the specified type
      casted_value = ParametersUtil.cast_value(value, type)
      if casted_value.nil?
        self.errors.add(:set_query, "value (#{value}) is not valid as a #{type}")
        return false
      end

      h[parameter] = { matcher => casted_value }
    end

    #h includes one or more hash(s) that can be converted to selector(s)
    self.query = h
    self.enable = para['eneble']
  end

  def set_one_query(para)
    return false if para.blank?

    h = {}
    parameter = para['param']
    defn = simulator.parameter_definition_for(parameter)
    type = simulator.parameter_definition_for(parameter).type
    value = para['value']
    matcher = para['matcher']

    # cast value to the specified type
    casted_value = ParametersUtil.cast_value(value, type)
    if casted_value.nil?
      self.errors.add(:set_query, "value (#{value}) is not valid as a #{type}")
      return false
    end

    h[parameter] = { matcher => casted_value }

    #h includes one or more hash(s) that can be converted to selector(s)
    self.query = h
    self.enable = para['enable']
  end

  public 
  def self.getNumTypeMatchers
    NumTypeMatchers
  end
  def self.getNumTypeMatcherStrings
    NumTypeMatcherStrings
  end
  def self.getBooleanTypeMatchers
    BooleanTypeMatchers
  end
  def self.getStringTypeMatchers
    StringTypeMatchers
  end
end
