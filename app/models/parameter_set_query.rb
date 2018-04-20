class ParameterSetQuery
  include Mongoid::Document
  field :name, type: String
  field :query, type: Hash
  belongs_to :simulator
  validates :simulator, presence: true
  validates :query, presence: true
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:simulator_id] }
  validate :validate_uniqueness_of_query
  validate :validate_format_of_query

  NumTypeMatchers = ["eq", "ne", "gt", "gte", "lt", "lte"]
  NumTypeMatcherStrings = ["==", "!=", ">", ">=", "<", "<="]
  StringTypeMatchers = ["start_with", "end_with", "include", "match"]

  def validate_uniqueness_of_query
    if self.query.blank?
      self.errors.add(:query, "must not be blank")
      return
    end

    if ParameterSetQuery.where(simulator: simulator, query: query).count > 0
      self.errors.add(:query, "must be unique")
    end
  end

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

  #convert format from string to selector
  def parameter_sets
    q = ParameterSet.where(simulator: simulator)
    self.query.each do |key,criteria|
      h = {}
      type = self.simulator.parameter_definition_for(key).type
      criteria.each do |matcher,value|
        unless supported_matchers(type).include?(matcher)
          raise "undefined matcher #{matcher} for #{type}"
        end
        if type == "String"
          h["v.#{key}"] = string_matcher_to_regexp(matcher, value)
        else
          h["v.#{key}"] = (matcher == "eq" ? value : {"$#{matcher}" => value} )
        end
        q = q.where(h)
      end
    end
    q
  end

  def selector
    parameter_sets.selector
  end

  private
  def supported_matchers(type)
    case type
    when "Integer", "Float"
      NumTypeMatchers
    when "String"
      StringTypeMatchers
    else
      raise "not supported type"
    end
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
  #set a query which is a hash expressed with string in key and val
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
  end
end
